import XCTest
@testable import LiveSwitcher

@MainActor
final class AudioRuntimeOwnershipTests: XCTestCase {
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

    func testFacadeAudioInputsChangedRecalculatesRuntimeAudio() {
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
        XCTAssertEqual(mutation.state.media.isPlaying, true)
        XCTAssertEqual(mutation.state.bgm.isPlaying, true)
        XCTAssertEqual(mutation.state.panic.isActive, false)
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

    func testEffectiveOutputSyncDispatchesFacadeAudioInputsChanged() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        viewModel.masterVolume = 0.5
        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        viewModel.avCoordinator.isPlaying = true
        viewModel.currentProgramItem = ProgramItem(
            title: "Video",
            subtitle: "VIDEO",
            sourceURL: URL(fileURLWithPath: "/tmp/video.mp4")
        )
        _ = viewModel.effectiveMediaOutputVolume()

        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "facadeAudioInputsChanged" })
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
