import XCTest
@testable import LiveSwitcher

@MainActor
final class AudioRuntimeOwnershipTests: XCTestCase {
    func testAudioDidSetDispatchesRuntimeActionAndAppliesRuntimeComputedRouting() {
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

private final class AudioRuntimeOwnershipPortSpy: AudioRoutingPort {
    private(set) var reasons: [AudioRoutingRuntimeChangeReason] = []
    private(set) var states: [LiveRuntimeState] = []

    func apply(reason: AudioRoutingRuntimeChangeReason, state: LiveRuntimeState) {
        reasons.append(reason)
        states.append(state)
    }
}
