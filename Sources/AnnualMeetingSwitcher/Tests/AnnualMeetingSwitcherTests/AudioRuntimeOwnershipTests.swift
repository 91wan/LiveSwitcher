import XCTest
@testable import LiveSwitcher

@MainActor
final class AudioRuntimeOwnershipTests: XCTestCase {
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
        state.bgm.isPlaying = false
        state.panic.isActive = false

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .facadeAudioInputsChanged(audioSnapshot(mediaPlaying: true, bgmPlaying: true, panic: true)),
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

    func testFacadeAudioInputsChangedDoesNotMutateMediaState() {
        var state = LiveRuntimeState()
        state.media.loadedURL = URL(fileURLWithPath: "/tmp/current.mp4")
        state.media.isPlaying = false
        state.media.didPlayToEnd = true
        state.media.currentTime = 12
        let originalMedia = state.media

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .facadeAudioInputsChanged(audioSnapshot(mediaPlaying: true)),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        XCTAssertEqual(mutation.state.media, originalMedia)
    }

    func testFacadeAudioInputsChangedDoesNotMutateBGMState() {
        var state = LiveRuntimeState()
        state.bgm.currentID = UUID()
        state.bgm.isPlaying = false
        state.bgm.progress = 0.4
        let originalBGM = state.bgm

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .facadeAudioInputsChanged(audioSnapshot(bgmPlaying: true)),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        XCTAssertEqual(mutation.state.bgm, originalBGM)
    }

    func testFacadeAudioInputsChangedDoesNotMutatePanicState() {
        var state = LiveRuntimeState()
        state.panic.isActive = false
        state.panic.generation = 4
        let originalPanic = state.panic

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .facadeAudioInputsChanged(audioSnapshot(panic: true)),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        XCTAssertEqual(mutation.state.panic, originalPanic)
    }

    func testAudioRoutingUsesAudioRoutingContext() {
        var state = LiveRuntimeState()
        state.audio.routingContext = AudioRoutingContext(
            isCurrentProgramMediaSource: true,
            isMediaPlaying: true,
            isBGMPlaying: true,
            isPanicMode: false
        )
        state.media.isPlaying = false
        state.bgm.isPlaying = false
        state.panic.isActive = true

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorChangedMasterVolume(0.5),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        let expected = AudioRoutingEngine.output(
            for: AudioRoutingInput(
                masterVolume: 0.5,
                mediaVolume: state.audio.mediaVolume,
                bgmVolume: state.audio.bgmVolume,
                audioStrategy: state.audio.strategy,
                isCurrentProgramMediaSource: true,
                isMediaPlaying: true,
                isBGMAudioTakeoverActive: state.audio.isBGMTakeoverActive,
                isSpeakerMode: state.audio.isSpeakerMode,
                isPanicMode: false,
                isMasterMuted: state.audio.isMasterMuted,
                isMediaMuted: state.audio.isMediaMuted,
                isBGMMuted: state.audio.isBGMMuted,
                speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
            )
        )

        XCTAssertEqual(mutation.state.audio.effectiveMedia, expected.media, accuracy: 0.0001)
        XCTAssertEqual(mutation.state.audio.effectiveBGM, expected.bgm, accuracy: 0.0001)
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
        let source = try sourceText("ViewModel.swift")
        let body = try XCTUnwrap(source.functionBody(named: "makeRuntimeStateSnapshot"))

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

    func testEffectiveBGMOutputGetterDoesNotDispatchAction() {
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
        runtimeState.audio.bgmVolume = 0.1
        runtimeState.audio.effectiveBGM = 0.31
        runtime.replaceStateForFacadeSync(runtimeState, clearActionLog: true)

        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.31, accuracy: 0.0001)
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
        viewModel.currentProgramItem = ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: URL(fileURLWithPath: "/tmp/video.mp4"))
        viewModel.avCoordinator.isPlaying = true
        viewModel.isBGMPlaying = true
        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        viewModel.masterVolume = 0.25

        XCTAssertEqual(audioRouting.states.last?.audio.routingContext.isCurrentProgramMediaSource, true)
        XCTAssertEqual(audioRouting.states.last?.audio.routingContext.isMediaPlaying, true)
        XCTAssertEqual(audioRouting.states.last?.audio.routingContext.isBGMPlaying, true)
    }

    func testMediaCallbackSyncsRuntimeAudioInputs() {
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        try? Data("fixture".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let item = ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: url)
        viewModel.addProgramItem(item)
        viewModel.switchToProgram(item)
        viewModel.runtime.updateEnvironment(LiveRuntimeEnvironment(bridgeMode: .audioOwned))
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)

        viewModel.dispatchRuntimeMediaCallback {
            .mediaPlaybackChanged(isPlaying: true, generation: $0)
        }

        XCTAssertTrue(viewModel.runtime.state.media.isPlaying)
        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isMediaPlaying)
        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isCurrentProgramMediaSource)
    }

    func testBGMCallbackSyncsRuntimeAudioInputs() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        let item = BGMItem(title: "BGM", url: URL(fileURLWithPath: "/tmp/audio-runtime-bgm.mp3"))
        viewModel.bgmItems = [item]
        viewModel.currentBGMItem = item
        viewModel.seedActiveRuntimeBGMCallbackForTesting(item: item, generation: 0)
        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        viewModel.dispatchRuntimeBGMCallback {
            .bgmPlaybackChanged(isPlaying: true, generation: $0)
        }

        XCTAssertTrue(runtime.state.bgm.isPlaying)
        XCTAssertTrue(runtime.state.audio.routingContext.isBGMPlaying)
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

    func testEffectiveBGMOutputReadsRuntimeStateWithoutLegacyRecompute() {
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

        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.23, accuracy: 0.0001)
    }

    func testApplyAudioRoutingRequiresRuntimeStateInProduction() throws {
        let source = try sourceText("ViewModel.swift")
        let body = try XCTUnwrap(source.functionBody(named: "applyAudioRoutingForRuntimeChange"))

        XCTAssertFalse(source.contains("runtimeState: LiveRuntimeState? = nil"))
        XCTAssertTrue(source.contains("legacyAudioRoutingOutputForSnapshotOnly"))
        XCTAssertFalse(source.contains("private var audioRoutingOutput"))
        XCTAssertTrue(source.contains("runtimeState: LiveRuntimeState"))
        XCTAssertTrue(source.contains("applyCurrentRuntimeAudioRouting"))
        XCTAssertTrue(body.contains("effectiveMedia: runtimeState.audio.effectiveMedia"))
    }

    func testUIModelsUseRuntimeBackedEffectiveValues() throws {
        let preflightSource = try sourceText("ViewModel+Preflight.swift")
        let setupAudioDockSource = try sourceText("Views/SetupAudioDock.swift")

        XCTAssertTrue(preflightSource.contains("effectiveMediaVolume: effectiveMediaOutputVolume()"))
        XCTAssertTrue(preflightSource.contains("effectiveBGMVolume: effectiveBGMOutputVolume()"))
        XCTAssertTrue(setupAudioDockSource.contains("effectiveMediaVolume: viewModel.effectiveMediaOutputVolume()"))
        XCTAssertTrue(setupAudioDockSource.contains("effectiveBGMVolume: viewModel.effectiveBGMOutputVolume()"))
    }

    func testLegacyAudioRoutingOutputOnlyUsedForSnapshotOrTests() throws {
        let source = try sourceText("ViewModel.swift")
        let uses = source.components(separatedBy: "legacyAudioRoutingOutputForSnapshotOnly").count - 1

        XCTAssertEqual(uses, 1)
    }

    func testAudioDidSetsDoNotApplyRoutingDirectly() throws {
        let source = try sourceText("ViewModel.swift")
        let audioBlock = try XCTUnwrap(
            source.range(of: "// MARK: - 音量控制")
                .flatMap { start in
                    source.range(of: "// MARK: - 转场配置", range: start.upperBound..<source.endIndex)
                        .map { end in String(source[start.lowerBound..<end.lowerBound]) }
                }
        )

        XCTAssertTrue(audioBlock.contains("dispatchRuntimeFacadeAction(.operatorChangedMasterVolume(masterVolume))"))
        XCTAssertTrue(audioBlock.contains("dispatchRuntimeFacadeAction(.operatorChangedMediaVolume(mediaVolume))"))
        XCTAssertTrue(audioBlock.contains("dispatchRuntimeFacadeAction(.operatorChangedBGMVolume(bgmVolume))"))
        XCTAssertFalse(audioBlock.contains("applyAudioRoutingForRuntimeChange"))
        XCTAssertFalse(audioBlock.contains("applyAudioRouting("))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try String(contentsOf: candidate, encoding: .utf8)
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }

    private func audioSnapshot(
        mediaPlaying: Bool = false,
        bgmPlaying: Bool = false,
        panic: Bool = false
    ) -> AudioFacadeSnapshot {
        AudioFacadeSnapshot(
            masterVolume: 0.5,
            mediaVolume: 0.8,
            bgmVolume: 0.2,
            strategy: .mixed,
            isMasterMuted: false,
            isMediaMuted: false,
            isBGMMuted: false,
            isSpeakerMode: false,
            isBGMTakeoverActive: false,
            isPanicMode: panic,
            isCurrentProgramMediaSource: true,
            isMediaPlaying: mediaPlaying,
            isBGMPlaying: bgmPlaying
        )
    }
}

private extension String {
    func functionBody(named functionName: String) -> String? {
        guard let nameRange = range(of: "func \(functionName)") else { return nil }
        guard let openingBrace = self[nameRange.lowerBound...].firstIndex(of: "{") else { return nil }

        var depth = 0
        var index = openingBrace
        while index < endIndex {
            let character = self[index]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(self[openingBrace...index])
                }
            }
            index = self.index(after: index)
        }
        return nil
    }
}

private final class AudioRuntimeOwnershipPortSpy: AudioRoutingPort {
    private(set) var reasons: [AudioRoutingRuntimeChangeReason] = []
    private(set) var states: [LiveRuntimeState] = []

    func apply(reason: AudioRoutingRuntimeChangeReason, state: LiveRuntimeState) {
        reasons.append(reason)
        states.append(state)
    }
}
