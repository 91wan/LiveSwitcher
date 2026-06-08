import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramQueueRuntimeViewModelMutationTests: XCTestCase {
    func testAddProgramItemsDispatchesRuntimeAction() {
        let viewModel = makeViewModel()
        let item = programItem("Added")

        viewModel.addProgramItems([item])

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorAddedProgramItems" })
        XCTAssertEqual(viewModel.runtime.state.program.items, [item])
    }

    func testAddProgramItemsDoesNotAppendDirectly() throws {
        let source = try programQueueSource()

        XCTAssertFalse(source.contains("programItems.append(contentsOf:"))
    }

    func testAddAgendaMarkerDispatchesRuntimeAction() {
        let viewModel = makeViewModel()

        viewModel.addAgendaMarker(title: "Break")

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorAddedAgendaMarker" })
        XCTAssertEqual(viewModel.programItems.last?.title, "Break")
    }

    func testAddAgendaMarkerDoesNotCalculateStartLocally() throws {
        let source = try programQueueSource()
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "addAgendaMarker"))

        XCTAssertFalse(body.contains("scheduledStartAt.addingTimeInterval"))
        XCTAssertTrue(body.contains("operatorAddedAgendaMarker"))
    }

    func testUpdateProgramItemScheduleDispatchesRuntimeAction() {
        let item = programItem("Scheduled")
        let viewModel = makeViewModel(initialItems: [item])

        viewModel.updateProgramItemSchedule(id: item.id, scheduledStartAt: Date(timeIntervalSince1970: 10), scheduledDuration: 20)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorUpdatedProgramItemSchedule" })
    }

    func testUpdateProgramItemScheduleUpdatesCurrentProgramFacadeAfterSync() {
        let item = programItem("Scheduled")
        let viewModel = makeViewModel(initialItems: [item])
        viewModel.dispatchRuntimeFacadeAction(.operatorSelectedProgram(item.id))
        let start = Date(timeIntervalSince1970: 10)

        viewModel.updateProgramItemSchedule(id: item.id, scheduledStartAt: start, scheduledDuration: 20)

        XCTAssertEqual(viewModel.currentProgramItem?.scheduledStartAt, start)
        XCTAssertEqual(viewModel.currentProgramItem?.scheduledDuration, 20)
    }

    func testRemoveProgramItemDispatchesRuntimeAction() {
        let item = programItem("Removed")
        let viewModel = makeViewModel(initialItems: [item])

        viewModel.removeProgramItem(withID: item.id)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorRemovedProgramItem" })
    }

    func testRemoveCurrentMediaStillStopsMediaThroughRuntimeBeforeQueueRemoval() {
        let item = programItem("Current")
        let viewModel = makeViewModel(initialItems: [item])
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())

        viewModel.removeProgramItem(withID: item.id)

        let actionNames = viewModel.runtime.actionLog.map(\.actionName)
        XCTAssertLessThan(
            try XCTUnwrap(actionNames.firstIndex(of: "operatorStoppedCurrentMedia")),
            try XCTUnwrap(actionNames.firstIndex(of: "operatorRemovedProgramItem"))
        )
    }

    func testRemoveCurrentDeckStillCallsDeckStopBeforeQueueRemoval() {
        let item = ProgramItem(title: "Deck", subtitle: "KEY", sourceURL: URL(fileURLWithPath: "/tmp/Deck.key"))
        let viewModel = makeViewModel(initialItems: [item])
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())
        var actionNamesAtDeckStop: [String] = []
        viewModel.programActivationSideEffects.stopDeck = {
            actionNamesAtDeckStop = viewModel.runtime.actionLog.map(\.actionName)
        }

        viewModel.removeProgramItem(withID: item.id)

        XCTAssertFalse(actionNamesAtDeckStop.contains("operatorRemovedProgramItem"))
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorRemovedProgramItem" })
    }

    func testRemoveCurrentHTMLStillClearsCurrentHTML() {
        let item = ProgramItem(title: "HTML", subtitle: "HTML", sourceURL: URL(fileURLWithPath: "/tmp/index.html"))
        let viewModel = makeViewModel(initialItems: [item])
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())
        viewModel.currentHTMLURL = item.sourceURL

        viewModel.removeProgramItem(withID: item.id)

        XCTAssertNil(viewModel.currentHTMLURL)
    }

    func testMoveProgramItemsDispatchesRuntimeAction() {
        let first = programItem("First")
        let second = programItem("Second")
        let viewModel = makeViewModel(initialItems: [first, second])

        viewModel.moveProgramItems(from: IndexSet(integer: 0), to: 2)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorMovedProgramItems" })
        XCTAssertEqual(viewModel.programItems.map(\.id), [second.id, first.id])
    }

    func testMoveProgramItemsDoesNotMoveArrayDirectly() throws {
        let source = try programQueueSource()

        XCTAssertFalse(source.contains("programItems.move(fromOffsets:"))
    }

    func testQueueMutationsSaveDataAfterFacadeSync() {
        let viewModel = makeViewModel()
        let item = programItem("Saved")
        var savedTitles: [String] = []
        viewModel.testHooks.saveDataDidRun = {
            savedTitles = viewModel.programItems.map(\.title)
        }

        viewModel.addProgramItems([item])

        XCTAssertEqual(savedTitles, ["Saved"])
    }

    private func programQueueSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramQueue.swift")
    }

    private func makeViewModel(initialItems: [ProgramItem] = []) -> SwitcherViewModel {
        var state = LiveRuntimeState()
        state.program.items = initialItems
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: .productionProgramSelectionOwning()
        )
        let suiteName = "ProgramQueueRuntimeViewModelMutationTests.\(UUID().uuidString)"
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
