import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramSelectionRuntimeSnapshotTests: XCTestCase {
    func testProgramSelectionOwnedRuntimeSnapshotPreservesRuntimeCurrentSelection() {
        let runtimeItem = programItem("Runtime")
        let staleFacadeItem = programItem("Stale")
        var state = LiveRuntimeState()
        state.program.items = [runtimeItem]
        state.program.currentID = runtimeItem.id
        state.program.currentSwitchedAt = Date(timeIntervalSince1970: 100)
        let viewModel = makeViewModel(initialState: state, bridgeMode: .programSelectionOwned)
        viewModel.applyCurrentProgramProjectionFromRuntime(staleFacadeItem, switchedAt: Date(timeIntervalSince1970: 1))

        viewModel.dispatchRuntimeFacadeAction(.operatorSetShowAgendaTimeline(true))

        XCTAssertEqual(viewModel.runtime.state.program.currentID, runtimeItem.id)
        XCTAssertNil(viewModel.runtime.state.program.currentDetachedItem)
        XCTAssertEqual(viewModel.runtime.state.program.currentSwitchedAt, Date(timeIntervalSince1970: 100))
    }

    func testProgramSelectionOwnedRuntimeSnapshotPreservesDetachedRuntimeCurrentSelection() {
        let detached = programItem("Detached")
        var state = LiveRuntimeState()
        state.program.currentID = detached.id
        state.program.currentDetachedItem = detached
        state.program.currentSwitchedAt = Date(timeIntervalSince1970: 100)
        let viewModel = makeViewModel(initialState: state, bridgeMode: .programSelectionOwned)
        viewModel.applyCurrentProgramProjectionFromRuntime(nil, switchedAt: nil)

        viewModel.dispatchRuntimeFacadeAction(.operatorSetShowAgendaTimeline(true))

        XCTAssertEqual(viewModel.runtime.state.program.currentID, detached.id)
        XCTAssertEqual(viewModel.runtime.state.program.currentDetachedItem, detached)
        XCTAssertEqual(viewModel.runtime.state.program.currentSwitchedAt, Date(timeIntervalSince1970: 100))
    }

    func testNonProgramSelectionOwnedSnapshotStillMirrorsFacadeCurrentProgram() {
        let item = programItem("Facade")
        let viewModel = makeViewModel(bridgeMode: .programQueueOwned)
        viewModel.applyProgramQueueProjectionFromRuntime([item])
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date(timeIntervalSince1970: 20))

        viewModel.dispatchRuntimeFacadeAction(.operatorSetShowAgendaTimeline(true))

        XCTAssertEqual(viewModel.runtime.state.program.currentID, item.id)
        XCTAssertEqual(viewModel.runtime.state.program.currentSwitchedAt, Date(timeIntervalSince1970: 20))
    }

    private func makeViewModel(
        initialState: LiveRuntimeState = LiveRuntimeState(),
        bridgeMode: LiveRuntimeBridgeMode
    ) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            initialState: initialState,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        let suiteName = "ProgramSelectionRuntimeSnapshotTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults, runtime: runtime)
    }

    private func programItem(_ title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "MEDIA", sourceURL: URL(fileURLWithPath: "/tmp/\(title).mp4"))
    }
}
