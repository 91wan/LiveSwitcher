import XCTest
@testable import LiveSwitcher

@MainActor
final class PersistentStateRuntimeLoadQueueTests: XCTestCase {
    func testApplyPersistentStateHydratesRuntimeProgramQueueWhenOwned() {
        let item = persistentRuntimeLoadProgramItem("Runtime Loaded")
        let viewModel = persistentRuntimeLoadMakeViewModel(bridgeMode: .programQueueOwned)

        viewModel.applyPersistentState(SwitcherPersistentState(programItems: [item]))

        XCTAssertEqual(viewModel.runtime.state.program.items, [item])
        XCTAssertEqual(viewModel.programItems, [item])
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "facadeLoadedProgramQueue" })
    }

    func testRecordingOnlyPersistentLoadMirrorsFacadeProgramQueueIntoRuntimeShadow() {
        let item = persistentRuntimeLoadProgramItem("Recording Queue")
        let viewModel = persistentRuntimeLoadMakeViewModel(bridgeMode: .recordingOnly)

        viewModel.applyPersistentState(SwitcherPersistentState(programItems: [item]))

        XCTAssertEqual(viewModel.runtime.state.program.items, [item])
        XCTAssertEqual(viewModel.programItems, [item])
    }

    func testPersistentLoadStillUsesFacadeLoadedProgramQueueWhenProgramQueueOwned() {
        let item = persistentRuntimeLoadProgramItem("Runtime Loaded")
        let viewModel = persistentRuntimeLoadMakeViewModel(bridgeMode: .programQueueOwned)

        viewModel.applyPersistentState(SwitcherPersistentState(programItems: [item]))

        XCTAssertEqual(viewModel.runtime.state.program.items, [item])
        XCTAssertEqual(viewModel.programItems, [item])
    }

    func testPersistentLoadStillProjectsFacadeQueueBeforeProgramQueueOwnership() {
        let item = persistentRuntimeLoadProgramItem("Facade Queue")
        let viewModel = persistentRuntimeLoadMakeViewModel(bridgeMode: .recordingOnly)

        viewModel.applyPersistentState(SwitcherPersistentState(programItems: [item]))

        XCTAssertEqual(viewModel.programItems, [item])
        XCTAssertEqual(viewModel.runtime.state.program.items, [item])
    }

    func testProgramQueueLoadDispatchOccursAfterSuppressionScopeEnds() {
        let item = persistentRuntimeLoadProgramItem("Queue Dispatch")
        let viewModel = persistentRuntimeLoadMakeViewModel(bridgeMode: .programQueueOwned)

        viewModel.applyPersistentState(SwitcherPersistentState(
            programItems: [item],
            consoleMode: .live
        ))

        XCTAssertEqual(viewModel.runtimeFacadeDispatchSuppressionDepth, 0)
        XCTAssertEqual(viewModel.runtime.state.program.items, [item])
    }

    func testProgramQueueLoadStillDoesNotPolluteActionLog() {
        let item = persistentRuntimeLoadProgramItem("Queue Dispatch")
        let viewModel = persistentRuntimeLoadMakeViewModel(bridgeMode: .programQueueOwned)

        viewModel.applyPersistentState(SwitcherPersistentState(programItems: [item]))

        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "facadeLoadedProgramQueue" })
    }
}
