import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeEffectInfrastructureSplitTests: XCTestCase {
    func testEffectRunnerRecordsRedactedSensitiveEffects() {
        let runner = LiveRuntimeEffectRunner.recording()
        let planID = UUID()
        let originalURL = URL(fileURLWithPath: "/private/customer/keynote.pptx")

        runner.run(
            [
                .runAppleScript(script: "tell app secret", action: "advance"),
                .saveCompanyDisplayName("Customer Confidential"),
                .executeProgramActivation(id: planID, plan: programActivationPlan(url: originalURL))
            ],
            currentState: LiveRuntimeState.init,
            dispatch: { _ in }
        )

        XCTAssertEqual(runner.recordedEffects[0], .runAppleScript(script: "<redacted>", action: "advance"))
        XCTAssertEqual(runner.recordedEffects[1], .saveCompanyDisplayName("<redacted>"))

        guard case .executeProgramActivation(planID, let redactedPlan) = runner.recordedEffects[2] else {
            return XCTFail("Expected recorded program activation effect")
        }
        XCTAssertEqual(redactedPlan.item.title, "<redacted>")
        XCTAssertEqual(redactedPlan.item.subtitle, "<redacted>")
        XCTAssertNil(redactedPlan.item.sourceURL)
        XCTAssertNotEqual(redactedPlan.postSelectionEffects, [.openPPTX(originalURL)])
    }

    func testEffectDomainPolicyCoversExecutionFamilies() {
        let supportEvent = LiveSupportEvent(timestamp: Date(timeIntervalSince1970: 0), kind: .systemVolumeSynced, detail: "ok")
        let bgmItem = BGMItem(title: "Walk-in", url: URL(fileURLWithPath: "/tmp/walk-in.mp3"))

        let samples: [(LiveRuntimeEffect, LiveRuntimeDomain)] = [
            (.applyAudioRouting(reason: .programChanged), .audio),
            (.loadBackgroundImage(URL(fileURLWithPath: "/tmp/bg.png")), .imageAssets),
            (.saveAudioStrategy(.bgmOnly), .persistence),
            (.loadMedia(URL(fileURLWithPath: "/tmp/video.mp4"), generation: 1), .media),
            (.prepareBGM(bgmItem, generation: 1), .bgm),
            (.schedulePanicBGMPause(
                generation: 1,
                snapshot: PanicPlaybackSnapshot(
                    currentProgramID: nil,
                    wasMediaPlaying: false,
                    currentBGMID: nil,
                    wasBGMPlaying: false
                ),
                delay: 1
            ), .panic),
            (.startProjection, .projection),
            (.startPPTEventTap, .ppt),
            (.executeProgramActivation(id: UUID(), plan: programActivationPlan()), .programActivation),
            (.runAppleScript(script: "tell app", action: "advance"), .automationCommand),
            (.scanPresentationQuery(id: UUID()), .presentationQuery),
            (.showAutomationNotice(automationNotice()), .automationNotice),
            (.recordSupportEvent(supportEvent), .support)
        ]

        for (effect, domain) in samples {
            XCTAssertEqual(effect.requiredBridgeDomain, domain, "\(effect)")
        }
    }

    func testRecordingOnlyRunnerDoesNotInvokeConnectedPorts() {
        let automation = ClosureAutomationPort()
        var invokedScripts: [String] = []
        automation.runHandler = { script, _ in invokedScripts.append(script) }
        let runner = LiveRuntimeEffectRunner(recordsOnly: true, automation: automation)

        runner.run(
            [.runAppleScript(script: "tell app secret", action: "advance")],
            currentState: LiveRuntimeState.init,
            dispatch: { _ in }
        )

        XCTAssertTrue(invokedScripts.isEmpty)
        XCTAssertEqual(runner.recordedEffects, [.runAppleScript(script: "<redacted>", action: "advance")])
    }

    func testRunnerRoutesOnlyCurrentMediaGeneration() {
        let media = ClosureMediaPlaybackPort()
        var playedGenerations: [Int] = []
        media.playHandler = { playedGenerations.append($0) }
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, media: media)
        var state = LiveRuntimeState()
        state.media.generation = 2

        runner.run(
            [.playMedia(generation: 1), .playMedia(generation: 2)],
            currentState: { state },
            dispatch: { _ in }
        )

        XCTAssertEqual(playedGenerations, [2])
        XCTAssertEqual(runner.recordedEffects, [.playMedia(generation: 1), .playMedia(generation: 2)])
    }

    func testRunnerRoutesOnlyCurrentBGMGenerationAndAllowsGlobalPlayMode() {
        let bgm = ClosureBGMPlaybackPort()
        var stoppedGenerations: [Int] = []
        var playModeChanges: [(BGMPlayMode, Int?)] = []
        bgm.stopHandler = { _, generation in stoppedGenerations.append(generation) }
        bgm.setPlayModeHandler = { mode, generation in playModeChanges.append((mode, generation)) }
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, bgm: bgm)
        var state = LiveRuntimeState()
        state.bgm.generation = 3

        runner.run(
            [
                .stopBGM(fade: 0.2, generation: 2),
                .stopBGM(fade: 0.2, generation: 3),
                .setBGMPlayMode(.loopOne, generation: nil)
            ],
            currentState: { state },
            dispatch: { _ in }
        )

        XCTAssertEqual(stoppedGenerations, [3])
        XCTAssertEqual(playModeChanges.map(\.0), [.loopOne])
        XCTAssertEqual(playModeChanges.map(\.1), [nil])
    }

    func testRunnerRoutesUngatedEffectsToTheirPorts() {
        let projection = ClosureProjectionPort()
        let ppt = ClosurePPTEventTapPort()
        let automationNoticePort = ClosureAutomationNoticePort()
        let presentationQuery = ClosurePresentationQueryPort()
        let audioRouting = ClosureAudioRoutingPort()
        let imageAssets = ClosureImageAssetPort()
        let persistence = ClosurePersistencePort()
        let support = ClosureSupportEventPort()

        var events: [String] = []
        projection.startHandler = { events.append("projection.start") }
        ppt.stopHandler = { reason in events.append("ppt.stop.\(reason.rawValue)") }
        automationNoticePort.showHandler = { notice in events.append("notice.\(notice.action)") }
        presentationQuery.scanHandler = { _, _ in events.append("presentation.scan") }
        audioRouting.applyHandler = { reason, _ in events.append("audio.\(reason)") }
        imageAssets.loadCornerLogoImageHandler = { _ in events.append("image.logo") }
        persistence.saveCompanyDisplayNameHandler = { _ in events.append("persistence.company") }
        support.recordHandler = { event in events.append("support.\(event.kind.rawValue)") }

        let runner = LiveRuntimeEffectRunner(
            recordsOnly: false,
            projection: projection,
            ppt: ppt,
            automationNotice: automationNoticePort,
            presentationQuery: presentationQuery,
            audioRouting: audioRouting,
            imageAssets: imageAssets,
            persistence: persistence,
            support: support
        )

        runner.run(
            [
                .startProjection,
                .stopPPTEventTap(reason: .operatorDisabled),
                .showAutomationNotice(automationNotice(action: "accessibilityPermission")),
                .scanPresentationQuery(id: UUID()),
                .applyAudioRouting(reason: .speakerChanged),
                .loadCornerLogoImage(URL(fileURLWithPath: "/tmp/logo.png")),
                .saveCompanyDisplayName("Customer"),
                .recordSupportEvent(LiveSupportEvent(timestamp: Date(timeIntervalSince1970: 0), kind: .projectionStarted, detail: "ok"))
            ],
            currentState: LiveRuntimeState.init,
            dispatch: { _ in }
        )

        XCTAssertEqual(
            events,
            [
                "projection.start",
                "ppt.stop.operatorDisabled",
                "notice.accessibilityPermission",
                "presentation.scan",
                "audio.speakerChanged",
                "image.logo",
                "persistence.company",
                "support.projection.started"
            ]
        )
        XCTAssertEqual(runner.recordedEffects.count, 8)
    }

    func testSwitcherRuntimePortBundleStillCreatesAllProductionPorts() {
        let runner = SwitcherRuntimePortBundle().makeEffectRunner()

        XCTAssertEqual(runner.connectedPortKinds, expectedProductionPortKinds)
    }

    func testSwitcherRuntimePortBundleConnectedPortsIncludePresentationQuerySet() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .panicOwned)
        XCTAssertEqual(viewModel.runtimeConnectedPortKinds, expectedProductionPortKinds)
    }

    private var expectedProductionPortKinds: Set<LiveRuntimeEffectPortKind> {
        [.media, .bgm, .bgmTimer, .panicDelay, .projection, .ppt, .automationNotice, .support, .automation, .presentationQuery, .programActivation, .audioRouting, .imageAssets, .persistence]
    }

    private func automationNotice(action: String = "advance") -> AutomationRuntimeNotice {
        AutomationRuntimeNotice(
            action: action,
            title: "Notice",
            message: "Message",
            severity: .warn,
            primaryAction: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            expiresAfter: nil
        )
    }

    private func programActivationPlan(url: URL = URL(fileURLWithPath: "/tmp/deck.pptx")) -> ProgramActivationPlan {
        let item = ProgramItem(title: "Opening", subtitle: "PPTX", sourceURL: url)
        return ProgramActivationPlan(
            item: item,
            runtimeSelection: .detached(item),
            preSelectionEffects: [.presentInvalidDeckAlert(url)],
            postSelectionEffects: [.openPPTX(url), .presentActiveDeck]
        )
    }
}
