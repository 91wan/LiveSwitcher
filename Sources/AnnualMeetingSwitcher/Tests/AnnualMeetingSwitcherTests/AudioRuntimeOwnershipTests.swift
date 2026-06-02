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

    func testEffectiveOutputVolumesReadRuntimeState() {
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
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.23, accuracy: 0.0001)
    }

    func testProductionAudioRoutingRuntimeChangeRequiresRuntimeState() throws {
        let source = try sourceText("ViewModel.swift")
        let body = try XCTUnwrap(source.functionBody(named: "applyAudioRoutingForRuntimeChange"))

        XCTAssertFalse(source.contains("runtimeState: LiveRuntimeState? = nil"))
        XCTAssertTrue(source.contains("legacyAudioRoutingOutputForSnapshotOnly"))
        XCTAssertFalse(source.contains("private var audioRoutingOutput"))
        XCTAssertTrue(source.contains("runtimeState: LiveRuntimeState"))
        XCTAssertTrue(source.contains("applyCurrentRuntimeAudioRouting"))
        XCTAssertTrue(body.contains("effectiveMedia: runtimeState.audio.effectiveMedia"))
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
