import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeMediaRestartBridgeTests: XCTestCase {
    func testRestartRoutesThroughRuntimeMediaPort() {
        let media = RuntimeMediaRestartPortSpy()
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, media: media),
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        let item = mediaProgram()
        var viewModelRestartCount = 0
        viewModel.programItems = [item]
        viewModel.currentProgramItem = item
        viewModel.runtime.replaceStateForFacadeSync(runtimeState(for: item))
        viewModel.programRestartFromBeginningHandler = { onReadyToPlay in
            viewModelRestartCount += 1
            onReadyToPlay()
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        viewModel.restartCurrentMediaFromBeginning()

        XCTAssertEqual(viewModelRestartCount, 0)
        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "operatorRestartedCurrentMedia" })
        XCTAssertTrue(media.events.contains { $0.hasPrefix("restart:") })
        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.media))
    }

    func testOwnershipDocumentStatesMediaRestartRuntimeEffectIsProductionExecuted() throws {
        let document = try runtimeOwnershipDocument()
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "/ ", with: "/")

        XCTAssertTrue(document.localizedStandardContains("Media playback is runtime-owned"))
        XCTAssertTrue(document.localizedStandardContains("load/play/pause/restart/stop/seek effects execute through `MediaPlaybackPort`"))
    }

    private func mediaProgram() -> ProgramItem {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        try? Data("fixture".utf8).write(to: url)
        return ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: url)
    }

    private func runtimeOwnershipDocument() throws -> String {
        let url = try repositoryRoot()
            .appendingPathComponent("docs/architecture/runtime-ownership.md")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func runtimeState(for item: ProgramItem) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.program.items = [item]
        state.program.currentID = item.id
        state.media.loadedURL = item.sourceURL
        state.media.isPlaying = true
        return state
    }

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("docs").path) {
                return directory
            }
        }
        throw XCTSkip("Could not locate repository root from test source path.")
    }
}

private final class RuntimeMediaRestartPortSpy: MediaPlaybackPort {
    private(set) var events: [String] = []

    func load(url: URL, generation: Int) {
        events.append("load:\(generation)")
    }

    func play(generation: Int) {
        events.append("play:\(generation)")
    }

    func pause(generation: Int) {
        events.append("pause:\(generation)")
    }

    func restart(generation: Int) {
        events.append("restart:\(generation)")
    }

    func seekToStart(generation: Int) {
        events.append("seekToStart:\(generation)")
    }

    func seekToEnd(generation: Int) {
        events.append("seekToEnd:\(generation)")
    }

    func stop(generation: Int) {
        events.append("stop:\(generation)")
    }

    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) {
        events.append("volume:\(generation)")
    }
}
