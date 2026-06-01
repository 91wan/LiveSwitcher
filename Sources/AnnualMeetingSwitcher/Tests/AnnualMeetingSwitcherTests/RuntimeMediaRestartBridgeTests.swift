import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeMediaRestartBridgeTests: XCTestCase {
    func testRestartRoutesAudioThroughRuntimeButPlaybackExecutionStaysInViewModel() {
        let audioRouting = RuntimeMediaRestartAudioPortSpy()
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, audioRouting: audioRouting)
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
        viewModel.programRestartFromBeginningHandler = { onReadyToPlay in
            viewModelRestartCount += 1
            onReadyToPlay()
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        audioRouting.reset()

        viewModel.restartCurrentMediaFromBeginning()

        XCTAssertEqual(viewModelRestartCount, 1)
        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "operatorRestartedCurrentMedia" })
        XCTAssertTrue(audioRouting.reasons.contains(.mediaPlaybackChanged))
        XCTAssertFalse(viewModel.runtimeConnectedPortKinds.contains(.media))
    }

    func testOwnershipDocumentStatesMediaRestartRuntimeEffectIsNotProductionExecuted() throws {
        let document = try runtimeOwnershipDocument()

        XCTAssertTrue(document.localizedStandardContains("media restart effect is not executed by runtime yet"))
        XCTAssertTrue(document.localizedStandardContains("ViewModel still executes media restart"))
        XCTAssertTrue(document.localizedStandardContains("audio routing port is wired"))
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

private final class RuntimeMediaRestartAudioPortSpy: AudioRoutingPort {
    private(set) var reasons: [AudioRoutingRuntimeChangeReason] = []

    func apply(reason: AudioRoutingRuntimeChangeReason, state: LiveRuntimeState) {
        reasons.append(reason)
    }

    func reset() {
        reasons.removeAll()
    }
}
