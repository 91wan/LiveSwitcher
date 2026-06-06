import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramQueueRuntimePersistenceTests: XCTestCase {
    func testLoadDataHydratesRuntimeProgramQueueWhenOwned() {
        let item = programItem("Loaded")
        let viewModel = makeViewModel()

        viewModel.applyPersistentState(SwitcherPersistentState(programItems: [item]))

        XCTAssertEqual(viewModel.runtime.state.program.items, [item])
    }

    func testLoadDataSyncsProgramItemsFacadeFromRuntimeWhenOwned() {
        let item = programItem("Loaded")
        let viewModel = makeViewModel()

        viewModel.applyPersistentState(SwitcherPersistentState(programItems: [item]))

        XCTAssertEqual(viewModel.programItems, [item])
    }

    func testLoadDataDoesNotSaveAfterFacadeLoadedProgramQueue() {
        let item = programItem("Loaded")
        let viewModel = makeViewModel()
        var didSave = false
        viewModel.testHooks.saveDataDidRun = { didSave = true }

        viewModel.applyPersistentState(SwitcherPersistentState(programItems: [item]))

        XCTAssertFalse(didSave)
    }

    func testLoadDataDoesNotDuplicateProgramItemsWhenCalledTwice() {
        let item = programItem("Loaded")
        let viewModel = makeViewModel()
        let state = SwitcherPersistentState(programItems: [item])

        viewModel.applyPersistentState(state)
        viewModel.applyPersistentState(state)

        XCTAssertEqual(viewModel.programItems, [item])
    }

    func testSaveDataStillPersistsRuntimeOwnedProgramQueueFacade() {
        let item = programItem("Saved")
        let viewModel = makeViewModel(initialItems: [item])

        let snapshot = viewModel.makePersistentStateSnapshot()

        XCTAssertEqual(snapshot.programItems, [item])
    }

    func testPersistenceLoadedProgramQueueActionIsNotLoggedAsOperatorAction() {
        let item = programItem("Loaded")
        let viewModel = makeViewModel()

        viewModel.applyPersistentState(SwitcherPersistentState(programItems: [item]))

        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "facadeLoadedProgramQueue" })
    }

    private func makeViewModel(initialItems: [ProgramItem] = []) -> SwitcherViewModel {
        var state = LiveRuntimeState()
        state.program.items = initialItems
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: .productionProgramQueueOwning()
        )
        let suiteName = "ProgramQueueRuntimePersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults, runtime: runtime)
        viewModel.syncProgramQueueFacadeFromRuntime()
        return viewModel
    }

    private func programItem(_ title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "MEDIA", sourceURL: URL(fileURLWithPath: "/tmp/\(title).mp4"))
    }
}
