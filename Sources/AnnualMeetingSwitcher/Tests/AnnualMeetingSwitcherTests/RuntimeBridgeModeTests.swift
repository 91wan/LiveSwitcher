import XCTest
@testable import LiveSwitcher

final class RuntimeBridgeModeTests: XCTestCase {
    func testBridgeModeCasesAreExplicitAndOrdered() {
        XCTAssertEqual(
            LiveRuntimeBridgeMode.allCases,
            [
                .recordingOnly,
                .audioOwned,
                .mediaOwned,
                .bgmOwned,
                .projectionOwned,
                .pptOwned,
                .automationNoticeOwned,
                .supportOwned,
                .automationCommandOwned,
                .presentationQueryOwned,
                .programQueueOwned,
                .programSelectionOwned,
                .programActivationOwned,
                .panicOwned,
                .fullRuntime
            ]
        )
    }

    func testBridgeModeDomainOwnershipIsCumulative() {
        XCTAssertTrue(LiveRuntimeBridgeMode.mediaOwned.owns(.audio))
        XCTAssertTrue(LiveRuntimeBridgeMode.mediaOwned.owns(.media))
        XCTAssertTrue(LiveRuntimeBridgeMode.bgmOwned.owns(.media))
        XCTAssertTrue(LiveRuntimeBridgeMode.projectionOwned.owns(.bgm))
        XCTAssertTrue(LiveRuntimeBridgeMode.pptOwned.owns(.projection))
        XCTAssertTrue(LiveRuntimeBridgeMode.pptOwned.owns(.ppt))
        XCTAssertTrue(LiveRuntimeBridgeMode.automationNoticeOwned.owns(.ppt))
        XCTAssertTrue(LiveRuntimeBridgeMode.automationNoticeOwned.owns(.automationNotice))
        XCTAssertFalse(LiveRuntimeBridgeMode.automationNoticeOwned.owns(.automation))
        XCTAssertFalse(LiveRuntimeBridgeMode.automationNoticeOwned.owns(.support))
        XCTAssertTrue(LiveRuntimeBridgeMode.supportOwned.owns(.automationNotice))
        XCTAssertTrue(LiveRuntimeBridgeMode.supportOwned.owns(.support))
        XCTAssertFalse(LiveRuntimeBridgeMode.supportOwned.owns(.automation))
        XCTAssertFalse(LiveRuntimeBridgeMode.supportOwned.owns(.automationCommand))
        XCTAssertTrue(LiveRuntimeBridgeMode.automationCommandOwned.owns(.support))
        XCTAssertTrue(LiveRuntimeBridgeMode.automationCommandOwned.owns(.automationCommand))
        XCTAssertFalse(LiveRuntimeBridgeMode.automationCommandOwned.owns(.automation))
        XCTAssertFalse(LiveRuntimeBridgeMode.automationCommandOwned.owns(.presentationQuery))
        XCTAssertTrue(LiveRuntimeBridgeMode.presentationQueryOwned.owns(.automationCommand))
        XCTAssertTrue(LiveRuntimeBridgeMode.presentationQueryOwned.owns(.presentationQuery))
        XCTAssertFalse(LiveRuntimeBridgeMode.presentationQueryOwned.owns(.automation))
        XCTAssertFalse(LiveRuntimeBridgeMode.presentationQueryOwned.owns(.programQueue))
        XCTAssertTrue(LiveRuntimeBridgeMode.programQueueOwned.owns(.presentationQuery))
        XCTAssertTrue(LiveRuntimeBridgeMode.programQueueOwned.owns(.programQueue))
        XCTAssertFalse(LiveRuntimeBridgeMode.programQueueOwned.owns(.programSelection))
        XCTAssertTrue(LiveRuntimeBridgeMode.programSelectionOwned.owns(.programQueue))
        XCTAssertTrue(LiveRuntimeBridgeMode.programSelectionOwned.owns(.programSelection))
        XCTAssertFalse(LiveRuntimeBridgeMode.programSelectionOwned.owns(.programActivation))
        XCTAssertTrue(LiveRuntimeBridgeMode.programActivationOwned.owns(.programQueue))
        XCTAssertTrue(LiveRuntimeBridgeMode.programActivationOwned.owns(.programSelection))
        XCTAssertTrue(LiveRuntimeBridgeMode.programActivationOwned.owns(.programActivation))
        XCTAssertFalse(LiveRuntimeBridgeMode.programActivationOwned.owns(.panic))
        XCTAssertTrue(LiveRuntimeBridgeMode.panicOwned.owns(.programActivation))
        XCTAssertTrue(LiveRuntimeBridgeMode.panicOwned.owns(.panic))
        XCTAssertFalse(LiveRuntimeBridgeMode.panicOwned.owns(.automation))
        XCTAssertFalse(LiveRuntimeBridgeMode.programQueueOwned.owns(.automation))
        XCTAssertFalse(LiveRuntimeBridgeMode.projectionOwned.owns(.support))
        XCTAssertFalse(LiveRuntimeBridgeMode.pptOwned.owns(.support))
    }

    func testAudioOwnedModeDoesNotPredictProgramOrMediaStateFromOperatorIntent() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]
        let originalMedia = state.media

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedProgram(item.id),
            environment: .productionAudioOwned(
                now: Date(timeIntervalSince1970: 100)
            )
        )

        XCTAssertNil(mutation.state.program.currentID)
        XCTAssertNil(mutation.state.program.currentSwitchedAt)
        XCTAssertEqual(mutation.state.media, originalMedia)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testAudioOwnedModeStillOwnsAudioMutationsAndRoutingEffects() {
        var state = LiveRuntimeState()
        state.audio.masterVolume = 1
        state.audio.mediaVolume = 1
        state.media.isPlaying = true
        state.program.currentDetachedItem = mediaProgram()

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorChangedMasterVolume(0.25),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        XCTAssertEqual(mutation.state.audio.masterVolume, 0.25)
        XCTAssertEqual(mutation.state.audio.effectiveMedia, 0.25, accuracy: 0.0001)
        XCTAssertEqual(mutation.effects, [.applyAudioRouting(reason: .operatorFaderChanged)])
    }

    func testAudioOwnedStillBlocksUnownedEffects() {
        var state = LiveRuntimeState()
        state.media.loadedURL = mediaProgram().sourceURL

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorToggledMediaPlayback,
            environment: .productionAudioOwned()
        )

        XCTAssertFalse(mutation.state.media.isPlaying)
        XCTAssertFalse(mutation.effects.contains { effect in
            if case .playMedia = effect { return true }
            return false
        })
    }

    func testProgramSelectionOwnedAllowsSelectionButStillBlocksOtherDomainEffects() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]
        state.bgm.items = [BGMItem(title: "BGM", url: URL(fileURLWithPath: "/tmp/bgm.mp3"))]
        state.projection.hasExternalDisplay = true

        let mediaMutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedProgram(item.id),
            environment: LiveRuntimeEnvironment(bridgeMode: .programSelectionOwned)
        )
        let bgmMutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedBGM(state.bgm.items[0].id),
            environment: LiveRuntimeEnvironment(bridgeMode: .programSelectionOwned)
        )
        let projectionMutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorToggledProjection,
            environment: LiveRuntimeEnvironment(bridgeMode: .programSelectionOwned)
        )

        XCTAssertTrue(mediaMutation.effects.contains {
            if case .loadMedia = $0 { return true }
            return false
        })
        XCTAssertFalse(bgmMutation.effects.isEmpty)
        XCTAssertFalse(projectionMutation.effects.isEmpty)
    }

    func testAudioOwnedModeStoresFacadeRoutingInputsInsideAudioState() {
        var state = LiveRuntimeState()
        state.media.isPlaying = false
        state.bgm.isPlaying = false
        state.panic.isActive = false

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .facadeAudioInputsChanged(
                AudioFacadeSnapshot(
                    masterVolume: 0.5,
                    mediaVolume: 1,
                    bgmVolume: 0.5,
                    strategy: .mixed,
                    isMasterMuted: false,
                    isMediaMuted: false,
                    isBGMMuted: false,
                    isSpeakerMode: false,
                    isBGMTakeoverActive: false,
                    isPanicMode: true,
                    isCurrentProgramMediaSource: true,
                    isMediaPlaying: true,
                    isBGMPlaying: true
                )
            ),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        XCTAssertEqual(
            mutation.state.audio.routingContext,
            AudioRoutingContext(
                isCurrentProgramMediaSource: true,
                isMediaPlaying: true,
                isBGMPlaying: true,
                isPanicMode: true
            )
        )
        XCTAssertFalse(mutation.state.media.isPlaying)
        XCTAssertFalse(mutation.state.bgm.isPlaying)
        XCTAssertFalse(mutation.state.panic.isActive)
    }

    func testFullRuntimeModeStillEmitsExecutableMediaEffects() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedProgram(item.id),
            environment: .fullRuntimeForTests(
                now: Date(timeIntervalSince1970: 100)
            )
        )

        XCTAssertTrue(mutation.effects.contains(.loadMedia(item.sourceURL!, generation: 1)))
        XCTAssertTrue(mutation.effects.contains(.playMedia(generation: 1)))
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .programChanged)))
    }

    func testFullRuntimeEffectsRequireExplicitEnvironment() {
        var state = LiveRuntimeState()
        state.media.loadedURL = mediaProgram().sourceURL

        let productionDefault = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorToggledMediaPlayback,
            environment: .productionAudioOwned()
        )
        let explicitFullRuntime = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorToggledMediaPlayback,
            environment: .fullRuntimeForTests()
        )

        XCTAssertTrue(productionDefault.effects.isEmpty)
        XCTAssertTrue(explicitFullRuntime.effects.contains { effect in
            if case .playMedia = effect { return true }
            return false
        })
    }

    private func mediaProgram() -> ProgramItem {
        ProgramItem(
            title: "Video",
            subtitle: "VIDEO",
            sourceURL: URL(fileURLWithPath: "/tmp/video.mp4")
        )
    }
}
