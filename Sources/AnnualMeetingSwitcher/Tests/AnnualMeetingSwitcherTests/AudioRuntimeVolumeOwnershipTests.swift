import XCTest
@testable import LiveSwitcher

@MainActor
final class AudioRuntimeVolumeOwnershipTests: XCTestCase {
    func testAudioRoutingDefaultsExposeSharedLiveAudioFadeDuration() {
        XCTAssertEqual(AudioRoutingDefaults.liveAudioFadeDuration, 2.0)
    }

    func testAudioFacadeMutationDispatchesRuntimeActionOnly() {
        let audioRouting = AudioRuntimeOwnershipPortSpy()
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, audioRouting: audioRouting),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )

        viewModel.masterVolume = 0.25

        XCTAssertEqual(runtime.state.audio.masterVolume, 0.25)
        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "operatorChangedMasterVolume" })
        XCTAssertEqual(audioRouting.reasons, [.operatorFaderChanged])
        XCTAssertEqual(audioRouting.states.last?.audio.effectiveMedia, runtime.state.audio.effectiveMedia)
        XCTAssertEqual(audioRouting.states.last?.audio.effectiveBGM, runtime.state.audio.effectiveBGM)
    }

    func testFacadeSyncStoresComputedEffectiveVolumesInRuntimeState() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.25
        viewModel.audioStrategy = .mixed
        viewModel.isBGMPlaying = true

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(runtime.state.audio.effectiveMedia, viewModel.effectiveMediaOutputVolume())
        XCTAssertEqual(runtime.state.audio.effectiveBGM, viewModel.effectiveBGMOutputVolume())
    }

    func testFacadeAudioInputsChangedUpdatesAudioRoutingContextOnly() {
        var state = LiveRuntimeState()
        state.media.isPlaying = false
        state.bgm.phase = .selected
        state.panic.isActive = false

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .facadeAudioInputsChanged(
                audioRuntimeOwnershipSnapshot(mediaPlaying: true, bgmPlaying: true, panic: true)
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
        XCTAssertEqual(mutation.state.media, state.media)
        XCTAssertEqual(mutation.state.bgm, state.bgm)
        XCTAssertEqual(mutation.state.panic, state.panic)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testRuntimeAudioOutputStillMatchesAudioRoutingEngine() {
        let snapshot = AudioFacadeSnapshot(
            masterVolume: 0.5,
            mediaVolume: 0.8,
            bgmVolume: 0.2,
            strategy: .mixed,
            isMasterMuted: false,
            isMediaMuted: false,
            isBGMMuted: false,
            isSpeakerMode: false,
            isBGMTakeoverActive: false,
            isPanicMode: false,
            isCurrentProgramMediaSource: true,
            isMediaPlaying: true,
            isBGMPlaying: true
        )

        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .facadeAudioInputsChanged(snapshot),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        XCTAssertEqual(mutation.state.audio.masterVolume, 0.5)
        XCTAssertEqual(mutation.state.audio.mediaVolume, 0.8)
        XCTAssertEqual(mutation.state.audio.bgmVolume, 0.2)
        XCTAssertEqual(mutation.state.audio.strategy, .mixed)
        XCTAssertEqual(mutation.state.audio.effectiveMedia, 0.4, accuracy: 0.0001)
        XCTAssertEqual(mutation.state.audio.effectiveBGM, 0.1, accuracy: 0.0001)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testFacadeSyncDoesNotWriteLegacyEffectiveAudioValues() throws {
        let source = try audioRuntimeOwnershipSourceText("ViewModel+RuntimeSnapshot.swift")
        let body = try XCTUnwrap(source.audioRuntimeOwnershipFunctionBody(named: "makeRuntimeStateSnapshot"))

        XCTAssertFalse(body.contains("legacyAudioRoutingOutputForSnapshotOnly"))
        XCTAssertFalse(body.contains("state.audio.effectiveMedia"))
        XCTAssertFalse(body.contains("state.audio.effectiveBGM"))
    }

    func testEffectiveMediaOutputGetterDoesNotDispatchAction() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        var runtimeState = runtime.state
        runtimeState.audio.masterVolume = 0.1
        runtimeState.audio.effectiveMedia = 0.42
        runtime.replaceStateForFacadeSync(runtimeState, clearActionLog: true)

        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.42, accuracy: 0.0001)
        XCTAssertTrue(runtime.actionLog.isEmpty)
    }

    func testEffectiveOutputGetterDoesNotChangeActionLogCount() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        var runtimeState = runtime.state
        runtimeState.audio.masterVolume = 0.1
        runtimeState.audio.effectiveMedia = 0.42
        runtimeState.audio.effectiveBGM = 0.31
        runtime.replaceStateForFacadeSync(runtimeState, clearActionLog: true)

        let initialCount = runtime.actionLog.count

        _ = viewModel.effectiveMediaOutputVolume()
        _ = viewModel.effectiveBGMOutputVolume()

        XCTAssertEqual(runtime.actionLog.count, initialCount)
    }

    func testAudioMutationSyncsRuntimeBeforeRouting() {
        let audioRouting = AudioRuntimeOwnershipPortSpy()
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, audioRouting: audioRouting),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(
            ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: URL(fileURLWithPath: "/tmp/video.mp4")),
            switchedAt: Date()
        )
        viewModel.avCoordinator.isPlaying = true
        viewModel.isBGMPlaying = true
        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        viewModel.masterVolume = 0.25

        XCTAssertEqual(audioRouting.states.last?.audio.routingContext.isCurrentProgramMediaSource, true)
        XCTAssertEqual(audioRouting.states.last?.audio.routingContext.isMediaPlaying, true)
        XCTAssertEqual(audioRouting.states.last?.audio.routingContext.isBGMPlaying, true)
    }

    func testEffectiveMediaOutputReadsRuntimeStateWithoutLegacyRecompute() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        var runtimeState = runtime.state
        runtimeState.audio.effectiveMedia = 0.17
        runtimeState.audio.effectiveBGM = 0.23
        runtime.replaceStateForFacadeSync(runtimeState)

        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.17, accuracy: 0.0001)
    }

    func testApplyAudioRoutingRequiresRuntimeStateInProduction() throws {
        let source = try audioRuntimeOwnershipSourceText("ViewModel+AudioRouting.swift")
        let body = try XCTUnwrap(source.audioRuntimeOwnershipFunctionBody(named: "applyAudioRoutingForRuntimeChange"))

        XCTAssertFalse(source.contains("runtimeState: LiveRuntimeState? = nil"))
        XCTAssertTrue(source.contains("legacyAudioRoutingOutputForSnapshotOnly"))
        XCTAssertFalse(source.contains("private var audioRoutingOutput"))
        XCTAssertTrue(source.contains("runtimeState: LiveRuntimeState"))
        XCTAssertTrue(source.contains("applyCurrentRuntimeAudioRouting"))
        XCTAssertTrue(body.contains("effectiveMedia: runtimeState.audio.effectiveMedia"))
    }

    func testUIModelsUseRuntimeBackedEffectiveValues() throws {
        let preflightSource = try audioRuntimeOwnershipSourceText("ViewModel+Preflight.swift")
        let setupAudioDockSource = try audioRuntimeOwnershipSourceText("Views/SetupAudioDock.swift")

        XCTAssertTrue(preflightSource.contains("effectiveMediaVolume: effectiveMediaOutputVolume()"))
        XCTAssertTrue(preflightSource.contains("effectiveBGMVolume: effectiveBGMOutputVolume()"))
        XCTAssertTrue(setupAudioDockSource.contains("effectiveMediaVolume: viewModel.effectiveMediaOutputVolume()"))
        XCTAssertTrue(setupAudioDockSource.contains("effectiveBGMVolume: viewModel.effectiveBGMOutputVolume()"))
    }

    func testLegacyAudioRoutingOutputOnlyUsedForSnapshotOrTests() throws {
        let source = try audioRuntimeOwnershipSourceText("ViewModel+AudioRouting.swift")
        let uses = source.components(separatedBy: "legacyAudioRoutingOutputForSnapshotOnly").count - 1

        XCTAssertEqual(uses, 1)
    }

    func testAudioDidSetsDoNotApplyRoutingDirectly() throws {
        let source = try audioRuntimeOwnershipSourceText("ViewModel.swift")
        let audioBlock = try XCTUnwrap(
            source.range(of: "// MARK: - 音量控制")
                .flatMap { start in
                    source.range(of: "// MARK: - 背景壁纸", range: start.upperBound..<source.endIndex)
                        .map { end in String(source[start.lowerBound..<end.lowerBound]) }
                }
        )

        XCTAssertFalse(source.contains("// MARK: - 转场配置"))
        XCTAssertFalse(source.contains("crossfadeDuration"))
        XCTAssertTrue(audioBlock.contains("dispatchRuntimeFacadeAction(.operatorChangedMasterVolume(masterVolume))"))
        XCTAssertTrue(audioBlock.contains("dispatchRuntimeFacadeAction(.operatorChangedMediaVolume(mediaVolume))"))
        XCTAssertTrue(audioBlock.contains("dispatchRuntimeFacadeAction(.operatorChangedBGMVolume(bgmVolume))"))
        XCTAssertFalse(audioBlock.contains("applyAudioRoutingForRuntimeChange"))
        XCTAssertFalse(audioBlock.contains("applyAudioRouting("))
    }
}
