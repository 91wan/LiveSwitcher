import XCTest
@testable import LiveSwitcher

@MainActor
final class MediaRuntimeCallbackIntegrityTests: XCTestCase {
    func testMediaCallbackIgnoredWhenCurrentProgramIsNonMedia() {
        let viewModel = productionViewModel()
        let item = mediaProgram()
        let html = htmlProgram()
        viewModel.addProgramItems([item, html])
        viewModel.switchToProgram(item)
        viewModel.applyCurrentProgramProjectionFromRuntime(html, switchedAt: Date())
        var state = viewModel.runtime.state
        state.program.items = [item, html]
        state.program.currentID = html.id
        state.program.currentDetachedItem = nil
        viewModel.runtime.replaceStateForFacadeSync(state, clearActionLog: true)

        viewModel.dispatchRuntimeMediaCallback {
            .mediaPlaybackChanged(isPlaying: true, generation: $0)
        }

        XCTAssertTrue(viewModel.runtime.actionLog.isEmpty)
    }

    func testMediaCallbackIgnoredWhenCurrentURLDoesNotMatchActiveRuntimeMediaURL() {
        let viewModel = productionViewModel()
        let item = mediaProgram()
        viewModel.addProgramItem(item)
        viewModel.switchToProgram(item)
        viewModel.avCoordinator.load(url: mediaURL())
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)

        viewModel.dispatchRuntimeMediaCallback {
            .mediaPlaybackChanged(isPlaying: true, generation: $0)
        }

        XCTAssertTrue(viewModel.runtime.actionLog.isEmpty)
    }

    func testMediaCallbackUsesActiveRuntimeMediaGeneration() {
        let viewModel = productionViewModel()
        let item = mediaProgram()
        viewModel.addProgramItem(item)
        viewModel.switchToProgram(item)
        let generation = viewModel.runtime.state.media.generation
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)

        viewModel.dispatchRuntimeMediaCallback {
            .mediaPlaybackChanged(isPlaying: false, generation: $0)
        }

        XCTAssertEqual(viewModel.runtime.state.media.generation, generation)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "mediaPlaybackChanged" })
    }

    func testStaleMediaPlaybackCallbackDoesNotReviveOldMedia() {
        let audioRouting = MediaRuntimeCallbackAudioRoutingSpy()
        let viewModel = viewModel(audioRouting: audioRouting)
        let item = mediaProgram()
        let html = htmlProgram()
        viewModel.addProgramItems([item, html])
        viewModel.switchToProgram(item)
        viewModel.switchToProgram(html)
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)
        audioRouting.reset()

        viewModel.dispatchRuntimeMediaCallback {
            .mediaPlaybackChanged(isPlaying: true, generation: $0)
        }

        XCTAssertFalse(viewModel.runtime.state.media.isPlaying)
        XCTAssertTrue(viewModel.runtime.actionLog.isEmpty)
        XCTAssertTrue(audioRouting.reasons.isEmpty)
    }

    func testSwitchToHTMLThenOldMediaCallbackDoesNotApplyRouting() {
        let audioRouting = MediaRuntimeCallbackAudioRoutingSpy()
        let viewModel = viewModel(audioRouting: audioRouting)
        let item = mediaProgram()
        let html = htmlProgram()
        viewModel.addProgramItems([item, html])
        viewModel.switchToProgram(item)
        viewModel.switchToProgram(html)
        audioRouting.reset()

        viewModel.dispatchRuntimeMediaCallback {
            .mediaReachedEnd(generation: $0)
        }

        XCTAssertTrue(audioRouting.reasons.isEmpty)
    }

    private func viewModel(audioRouting: MediaRuntimeCallbackAudioRoutingSpy) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, audioRouting: audioRouting),
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        )
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
    }

    private func productionViewModel() -> SwitcherViewModel {
        SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false
        )
    }

    private func mediaProgram() -> ProgramItem {
        ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: mediaURL())
    }

    private func htmlProgram() -> ProgramItem {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")
        try? Data("<html></html>".utf8).write(to: url)
        return ProgramItem(title: "HTML", subtitle: "HTML", sourceURL: url)
    }

    private func mediaURL() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        try? Data("fixture".utf8).write(to: url)
        return url
    }
}

private final class MediaRuntimeCallbackAudioRoutingSpy: AudioRoutingPort {
    private(set) var reasons: [AudioRoutingRuntimeChangeReason] = []

    func apply(reason: AudioRoutingRuntimeChangeReason, state: LiveRuntimeState) {
        reasons.append(reason)
    }

    func reset() {
        reasons = []
    }
}
