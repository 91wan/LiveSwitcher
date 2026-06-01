import XCTest
@testable import LiveSwitcher

@MainActor
final class LiveRuntimeMediaBridgeTests: XCTestCase {
    func testMediaPlaybackActionProducesPlaybackAndRoutingEffects() {
        var state = LiveRuntimeState()
        state.media.loadedURL = URL(fileURLWithPath: "/tmp/video.mp4")

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorToggledMediaPlayback,
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertTrue(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.effects.contains(.playMedia(generation: state.media.generation)))
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .mediaPlaybackChanged)))
    }

    func testMediaPlaybackCallbackProducesRoutingEffectForCurrentGeneration() {
        var state = LiveRuntimeState()
        state.media.generation = 4

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .mediaPlaybackChanged(isPlaying: true, generation: 4),
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertTrue(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .mediaPlaybackChanged)))
    }

    func testViewModelProgramSwitchDispatchesRuntimeProgramAction() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let item = mediaProgram()
        viewModel.addProgramItem(item)

        viewModel.switchToProgram(item)

        XCTAssertEqual(viewModel.runtime.state.program.currentID, item.id)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedProgram" })
    }

    func testViewModelPlaybackToggleDispatchesRuntimeMediaAction() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let item = mediaProgram()
        viewModel.programItems = [item]
        viewModel.currentProgramItem = item

        viewModel.toggleMainVideoPlayback()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorToggledMediaPlayback" })
    }

    func testViewModelDispatchesThroughInjectedRuntimeStore() {
        let runtime = LiveRuntimeStore(effectRunner: .recording())
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        let item = mediaProgram()
        viewModel.programItems = [item]
        viewModel.currentProgramItem = item

        viewModel.toggleMainVideoPlayback()

        XCTAssertTrue(viewModel.runtime === runtime)
        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "operatorToggledMediaPlayback" })
        XCTAssertTrue(runtime.recordedEffects.contains(.playMedia(generation: runtime.state.media.generation)))
    }

    func testViewModelRestartDispatchesRuntimeRestartAction() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let item = mediaProgram()
        viewModel.programItems = [item]
        viewModel.currentProgramItem = item

        viewModel.restartCurrentMediaFromBeginning()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorRestartedCurrentMedia" })
    }

    func testViewModelPlaybackEndedDispatchesRuntimeEndCallback() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let item = mediaProgram()
        viewModel.programItems = [item]
        viewModel.currentProgramItem = item

        viewModel.handlePlaybackEnded()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "mediaReachedEnd" })
    }

    private func mediaProgram() -> ProgramItem {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        try? Data("fixture".utf8).write(to: url)
        return ProgramItem(
            title: "Video",
            subtitle: "VIDEO",
            sourceURL: url
        )
    }
}
