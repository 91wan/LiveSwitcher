import XCTest
@testable import LiveSwitcher

final class RuntimeEffectFilteringCumulativeTests: XCTestCase {
    func testBGMPlaybackEffectsRequireBGMOwnedDomainBeforeMigration() {
        let item = bgmItem()

        [
            LiveRuntimeEffect.prepareBGM(item, generation: 1),
            .playBGM(generation: 1),
            .pauseBGM(generation: 1),
            .stopBGM(fade: 0.5, generation: 1),
            .setBGMVolume(0.4, fade: 0.2, generation: 1),
            .seekBGMToBeginning(generation: 1),
            .seekBGMToProgress(0.5, generation: 1),
            .setBGMPlayMode(.loopOne, generation: 1),
            .startBGMTimer(generation: 1),
            .stopBGMTimer(generation: 1)
        ].forEach { effect in
            XCTAssertEqual(effect.requiredBridgeDomain, .bgm)
        }
    }

    func testMediaAndBGMEffectDomainsStaySeparated() {
        let mediaURL = URL(fileURLWithPath: "/tmp/runtime-effect-domain-video.mp4")
        let bgm = bgmItem()

        XCTAssertEqual(LiveRuntimeEffect.loadMedia(mediaURL, generation: 1).requiredBridgeDomain, .media)
        XCTAssertEqual(LiveRuntimeEffect.playMedia(generation: 1).requiredBridgeDomain, .media)
        XCTAssertEqual(LiveRuntimeEffect.prepareBGM(bgm, generation: 1).requiredBridgeDomain, .bgm)
        XCTAssertEqual(LiveRuntimeEffect.saveBGMPlayMode(.loopOne).requiredBridgeDomain, .persistence)
    }

    func testSaveBGMPlayModeRequiresPersistenceDomain() {
        XCTAssertEqual(LiveRuntimeEffect.saveBGMPlayMode(.loopOne).requiredBridgeDomain, .persistence)
    }

    func testShowAutomationNoticeRequiresAutomationNoticeDomain() {
        let notice = AutomationRuntimeNoticePolicy.make(action: "keynote.next-slide")

        XCTAssertEqual(LiveRuntimeEffect.showAutomationNotice(notice).requiredBridgeDomain, .automationNotice)
    }

    func testExpireAutomationNoticeRequiresAutomationNoticeDomain() {
        XCTAssertEqual(
            LiveRuntimeEffect.expireAutomationNotice(UUID(), at: Date(timeIntervalSince1970: 1)).requiredBridgeDomain,
            .automationNotice
        )
    }

    func testRunAppleScriptRequiresAutomationCommandDomain() {
        XCTAssertEqual(
            LiveRuntimeEffect.runAppleScript(script: "tell app", action: "keynote.next-slide").requiredBridgeDomain,
            .automationCommand
        )
    }

    func testScanPresentationQueryRequiresPresentationQueryDomain() {
        XCTAssertEqual(LiveRuntimeEffect.scanPresentationQuery(id: UUID()).requiredBridgeDomain, .presentationQuery)
    }

    func testProductionPresentationQueryModeOwnsQueryButNotFullAutomationDomain() {
        XCTAssertFalse(LiveRuntimeEnvironment.productionSupportOwning().bridgeMode.owns(.automation))
        XCTAssertFalse(LiveRuntimeEnvironment.productionSupportOwning().bridgeMode.owns(.automationCommand))
        XCTAssertTrue(LiveRuntimeEnvironment.productionAutomationCommandOwning().bridgeMode.owns(.automationCommand))
        XCTAssertFalse(LiveRuntimeEnvironment.productionAutomationCommandOwning().bridgeMode.owns(.automation))
        XCTAssertTrue(LiveRuntimeEnvironment.productionPresentationQueryOwning().bridgeMode.owns(.presentationQuery))
        XCTAssertFalse(LiveRuntimeEnvironment.productionPresentationQueryOwning().bridgeMode.owns(.automation))
        XCTAssertTrue(LiveRuntimeEnvironment.productionProgramQueueOwning().bridgeMode.owns(.programQueue))
        XCTAssertTrue(LiveRuntimeEnvironment.productionProgramQueueOwning().bridgeMode.owns(.presentationQuery))
        XCTAssertFalse(LiveRuntimeEnvironment.productionProgramQueueOwning().bridgeMode.owns(.automation))
        XCTAssertTrue(LiveRuntimeEnvironment.fullRuntimeForTests().bridgeMode.owns(.automation))
    }

    func testSupportOwnedModeBlocksRunAppleScriptEffect() {
        let effect = LiveRuntimeEffect.runAppleScript(script: "tell app", action: "keynote.next-slide")

        XCTAssertEqual(effect.requiredBridgeDomain, .automationCommand)
        XCTAssertFalse(LiveRuntimeBridgeMode.supportOwned.owns(effect.requiredBridgeDomain))
    }

    func testAudioOwnedAllowsSaveBGMPlayModeThroughPersistenceDomain() {
        let mutation = reduce(.operatorSelectedBGMPlayMode(.loopOne), bridgeMode: .audioOwned)

        XCTAssertTrue(mutation.effects.contains(.saveBGMPlayMode(.loopOne)))
    }

    func testMediaOwnedAllowsSaveBGMPlayModeThroughPersistenceDomain() {
        let mutation = reduce(.operatorSelectedBGMPlayMode(.loopOne), bridgeMode: .mediaOwned)

        XCTAssertTrue(mutation.effects.contains(.saveBGMPlayMode(.loopOne)))
    }

    func testBGMOwningModeAllowsSaveBGMPlayMode() {
        let mutation = reduce(.operatorSelectedBGMPlayMode(.loopOne), bridgeMode: .bgmOwned)

        XCTAssertTrue(mutation.effects.contains(.saveBGMPlayMode(.loopOne)))
    }

    func testProjectionOwningModeAllowsSaveBGMPlayMode() {
        let mutation = reduce(.operatorSelectedBGMPlayMode(.loopOne), bridgeMode: .projectionOwned)

        XCTAssertTrue(mutation.effects.contains(.saveBGMPlayMode(.loopOne)))
    }

    func testBGMOwningModeStillAllowsMediaEffects() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]

        let mutation = reduce(state, .operatorSelectedProgram(item.id), bridgeMode: .bgmOwned)

        XCTAssertTrue(mutation.effects.contains(.loadMedia(item.sourceURL!, generation: 1)))
        XCTAssertTrue(mutation.effects.contains(.playMedia(generation: 1)))
    }

    func testProjectionOwningModeStillAllowsMediaAndBGMEffects() {
        let media = mediaProgram()
        let bgm = bgmItem()
        var state = LiveRuntimeState()
        state.program.items = [media]
        state.bgm.items = [bgm]

        let mediaMutation = reduce(state, .operatorSelectedProgram(media.id), bridgeMode: .projectionOwned)
        let bgmMutation = reduce(state, .operatorSelectedBGM(bgm.id), bridgeMode: .projectionOwned)

        XCTAssertTrue(mediaMutation.effects.contains(.loadMedia(media.sourceURL!, generation: 1)))
        XCTAssertTrue(bgmMutation.effects.contains(.prepareBGM(bgm, generation: 1)))
        XCTAssertTrue(bgmMutation.effects.contains(.startBGMTimer(generation: 1)))
    }

    func testBGMOwningModeBlocksProjectionEffects() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true

        let mutation = reduce(state, .operatorToggledProjection, bridgeMode: .bgmOwned)

        XCTAssertFalse(mutation.effects.contains(.startProjection))
        XCTAssertFalse(mutation.effects.contains(.showOutputWindow))
    }

    func testProjectionOwningModeBlocksPPTAutomationAndSupportEffects() {
        let support = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 10),
            kind: .projectionStarted,
            detail: "source=test"
        )

        [
            reduce(.pptEventTapStarted, bridgeMode: .projectionOwned),
            reduce(.automationNoticeRequested(action: "keynote.open"), bridgeMode: .projectionOwned),
            reduce(.supportEventRecorded(support), bridgeMode: .projectionOwned)
        ].forEach { mutation in
            XCTAssertFalse(mutation.effects.contains(.startPPTEventTap))
            XCTAssertFalse(mutation.effects.contains { effect in
                if case .showAutomationNotice = effect { return true }
                return false
            })
            XCTAssertFalse(mutation.effects.contains(.recordSupportEvent(support)))
        }
    }

    func testPPTOwningModeAllowsPPTButBlocksAutomationAndSupportEffects() {
        let support = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 10),
            kind: .pageInterceptEnabled,
            detail: "source=test"
        )

        let pptMutation = reduce(.operatorSetPPTMode(true, source: .liveMode), bridgeMode: .pptOwned)
        let automationMutation = reduce(.automationNoticeRequested(action: "keynote.open"), bridgeMode: .pptOwned)
        let supportMutation = reduce(.supportEventRecorded(support), bridgeMode: .pptOwned)

        XCTAssertEqual(pptMutation.effects, [.startPPTEventTap])
        XCTAssertFalse(automationMutation.effects.contains { effect in
            if case .showAutomationNotice = effect { return true }
            return false
        })
        XCTAssertFalse(supportMutation.effects.contains(.recordSupportEvent(support)))
    }

    func testAutomationNoticeOwnedModeAllowsAutomationNoticeButBlocksAutomationAndSupportEffects() {
        let support = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 10),
            kind: .pageInterceptEnabled,
            detail: "source=test"
        )

        let noticeMutation = reduce(.automationNoticeRequested(action: "keynote.open"), bridgeMode: .automationNoticeOwned)
        let scriptMutation = reduce(.automationFailed(action: "keynote.open", sanitizedMessage: "failed"), bridgeMode: .automationNoticeOwned)
        let supportMutation = reduce(.supportEventRecorded(support), bridgeMode: .automationNoticeOwned)

        XCTAssertTrue(noticeMutation.effects.contains { effect in
            if case .showAutomationNotice = effect { return true }
            return false
        })
        XCTAssertFalse(scriptMutation.effects.contains { effect in
            if case .runAppleScript = effect { return true }
            return false
        })
        XCTAssertFalse(supportMutation.effects.contains(.recordSupportEvent(support)))
    }

    func testSupportOwnedModeAllowsSupportButBlocksAutomationExecutionEffects() {
        let support = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 10),
            kind: .pageInterceptEnabled,
            detail: "source=test"
        )

        let supportMutation = reduce(.supportEventRecorded(support), bridgeMode: .supportOwned)
        let scriptMutation = reduce(.automationFailed(action: "keynote.open", sanitizedMessage: "failed"), bridgeMode: .supportOwned)

        XCTAssertTrue(supportMutation.effects.contains(.recordSupportEvent(support)))
        XCTAssertFalse(scriptMutation.effects.contains { effect in
            if case .runAppleScript = effect { return true }
            return false
        })
    }

    func testMediaOwnedBlocksBGMEffects() {
        let bgm = bgmItem()
        var state = LiveRuntimeState()
        state.bgm.items = [bgm]

        let mutation = reduce(state, .operatorSelectedBGM(bgm.id), bridgeMode: .mediaOwned)

        XCTAssertFalse(mutation.effects.contains(.prepareBGM(bgm, generation: 1)))
        XCTAssertFalse(mutation.effects.contains(.startBGMTimer(generation: 1)))
    }

    func testMediaOwnedAllowsMediaEffects() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]

        let mutation = reduce(state, .operatorSelectedProgram(item.id), bridgeMode: .mediaOwned)

        XCTAssertTrue(mutation.effects.contains(.loadMedia(item.sourceURL!, generation: 1)))
        XCTAssertTrue(mutation.effects.contains(.playMedia(generation: 1)))
    }

    func testRecordingOnlyBlocksImageAssetEffects() {
        let url = URL(fileURLWithPath: "/tmp/background.png")
        let mutation = reduce(.operatorSetActiveWallpaperURL(url), bridgeMode: .recordingOnly)

        XCTAssertFalse(mutation.effects.contains(.loadBackgroundImage(url)))
    }

    func testRecordingOnlyBlocksPersistenceEffects() {
        let mutation = reduce(.operatorSelectedAudioStrategy(.mixed), bridgeMode: .recordingOnly)

        XCTAssertFalse(mutation.effects.contains(.saveAudioStrategy(.mixed)))
    }

    func testAudioOwnedAllowsImageAssetEffects() {
        let url = URL(fileURLWithPath: "/tmp/background.png")
        let mutation = reduce(.operatorSetActiveWallpaperURL(url), bridgeMode: .audioOwned)

        XCTAssertTrue(mutation.effects.contains(.loadBackgroundImage(url)))
    }

    func testAudioOwnedAllowsPersistenceEffects() {
        let mutation = reduce(.operatorSelectedAudioStrategy(.mixed), bridgeMode: .audioOwned)

        XCTAssertTrue(mutation.effects.contains(.saveAudioStrategy(.mixed)))
    }

    func testAutomationCommandOwnedAllowsImageAssetEffects() {
        let url = URL(fileURLWithPath: "/tmp/background.png")
        let mutation = reduce(.operatorSetActiveWallpaperURL(url), bridgeMode: .automationCommandOwned)

        XCTAssertTrue(mutation.effects.contains(.loadBackgroundImage(url)))
    }

    func testAutomationCommandOwnedAllowsPersistenceEffects() {
        let mutation = reduce(.operatorSelectedAudioStrategy(.mixed), bridgeMode: .automationCommandOwned)

        XCTAssertTrue(mutation.effects.contains(.saveAudioStrategy(.mixed)))
    }

    func testAutomationCommandOwnedStillAllowsRunAppleScript() {
        let mutation = reduce(
            .automationScriptRequested(script: "tell app", action: "keynote.next-slide"),
            bridgeMode: .automationCommandOwned
        )

        XCTAssertTrue(mutation.effects.contains(.runAppleScript(script: "tell app", action: "keynote.next-slide")))
    }

    private func reduce(
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        reduce(LiveRuntimeState(), action, bridgeMode: bridgeMode)
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
    }

    private func mediaProgram() -> ProgramItem {
        ProgramItem(
            title: "Video",
            subtitle: "VIDEO",
            sourceURL: URL(fileURLWithPath: "/tmp/runtime-cumulative-video.mp4")
        )
    }

    private func bgmItem() -> BGMItem {
        BGMItem(title: "BGM", url: URL(fileURLWithPath: "/tmp/runtime-cumulative-bgm.mp3"))
    }
}
