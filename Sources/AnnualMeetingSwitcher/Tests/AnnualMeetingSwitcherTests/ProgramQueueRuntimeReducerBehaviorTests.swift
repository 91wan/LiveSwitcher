import XCTest
@testable import LiveSwitcher

final class ProgramQueueRuntimeReducerBehaviorTests: XCTestCase {
    func testAddProgramItemsAppendsItems() {
        let item = programItem("Added")
        let mutation = reduce(LiveRuntimeState(), .operatorAddedProgramItems([item]))

        XCTAssertEqual(mutation.state.program.items, [item])
    }

    func testAddProgramItemsNoopsForEmptyInput() {
        let state = queueState([programItem("Existing")])
        let mutation = reduce(state, .operatorAddedProgramItems([]))

        XCTAssertEqual(mutation.state.program, state.program)
    }

    func testRemoveProgramItemRemovesMatchingItem() {
        let first = programItem("First")
        let second = programItem("Second")
        let mutation = reduce(queueState([first, second]), .operatorRemovedProgramItem(first.id))

        XCTAssertEqual(mutation.state.program.items, [second])
    }

    func testRemoveProgramItemClearsCurrentQueuedSelection() {
        let item = programItem("Current")
        var state = queueState([item])
        state.program.currentID = item.id
        state.program.currentSwitchedAt = Date(timeIntervalSince1970: 10)

        let mutation = reduce(state, .operatorRemovedProgramItem(item.id))

        XCTAssertNil(mutation.state.program.currentID)
        XCTAssertNil(mutation.state.program.currentDetachedItem)
        XCTAssertNil(mutation.state.program.currentSwitchedAt)
    }

    func testRemoveProgramItemDoesNotClearDetachedCurrentSelectionWithDifferentID() {
        let queued = programItem("Queued")
        let detached = programItem("Detached")
        var state = queueState([queued])
        state.program.currentID = detached.id
        state.program.currentDetachedItem = detached

        let mutation = reduce(state, .operatorRemovedProgramItem(queued.id))

        XCTAssertEqual(mutation.state.program.currentID, detached.id)
        XCTAssertEqual(mutation.state.program.currentDetachedItem, detached)
    }

    func testMoveProgramItemsMovesValidOffsets() {
        let first = programItem("First")
        let second = programItem("Second")
        let third = programItem("Third")
        let mutation = reduce(
            queueState([first, second, third]),
            .operatorMovedProgramItems(fromOffsets: [0], toOffset: 3)
        )

        XCTAssertEqual(mutation.state.program.items.map(\.id), [second.id, third.id, first.id])
    }

    func testMoveProgramItemsIgnoresInvalidOffsets() {
        let item = programItem("Only")
        let state = queueState([item])
        let mutation = reduce(state, .operatorMovedProgramItems(fromOffsets: [5], toOffset: 1))

        XCTAssertEqual(mutation.state.program.items, [item])
    }

    func testUpdateProgramItemScheduleUpdatesExistingItem() {
        let item = programItem("Scheduled")
        let start = Date(timeIntervalSince1970: 100)
        let mutation = reduce(
            queueState([item]),
            .operatorUpdatedProgramItemSchedule(id: item.id, scheduledStartAt: start, scheduledDuration: 45)
        )

        XCTAssertEqual(mutation.state.program.items.first?.scheduledStartAt, start)
        XCTAssertEqual(mutation.state.program.items.first?.scheduledDuration, 45)
    }

    func testUpdateProgramItemScheduleNoopsForMissingItem() {
        let item = programItem("Scheduled")
        let state = queueState([item])
        let mutation = reduce(
            state,
            .operatorUpdatedProgramItemSchedule(id: UUID(), scheduledStartAt: Date(), scheduledDuration: 45)
        )

        XCTAssertEqual(mutation.state.program.items, [item])
    }

    func testAddAgendaMarkerUsesInputWithoutPreviousEndInference() {
        let start = Date(timeIntervalSince1970: 100)
        var item = programItem("Video")
        item.scheduledStartAt = start
        item.scheduledDuration = 60

        let mutation = reduce(
            queueState([item]),
            .operatorAddedAgendaMarker(AgendaMarkerInput(title: "茶歇", scheduledStartAt: nil, duration: 15 * 60))
        )

        XCTAssertEqual(mutation.state.program.items.last?.title, "茶歇")
        XCTAssertNil(mutation.state.program.items.last?.scheduledStartAt)
        XCTAssertEqual(mutation.state.program.items.last?.scheduledDuration, 15 * 60)
    }

    func testLoadProgramQueueFromFacadeReplacesItems() {
        let existing = programItem("Existing")
        let loaded = programItem("Loaded")
        let mutation = reduce(queueState([existing]), .facadeLoadedProgramQueue([loaded]))

        XCTAssertEqual(mutation.state.program.items, [loaded])
    }

    func testLoadProgramQueueFromFacadeClearsMissingCurrentQueuedSelection() {
        let current = programItem("Current")
        var state = queueState([current])
        state.program.currentID = current.id
        state.program.currentSwitchedAt = Date(timeIntervalSince1970: 10)

        let mutation = reduce(state, .facadeLoadedProgramQueue([]))

        XCTAssertNil(mutation.state.program.currentID)
        XCTAssertNil(mutation.state.program.currentDetachedItem)
        XCTAssertNil(mutation.state.program.currentSwitchedAt)
    }

    func testLoadProgramQueueFromFacadePreservesDetachedCurrentSelection() {
        let detached = programItem("Detached")
        var state = queueState([])
        state.program.currentID = detached.id
        state.program.currentDetachedItem = detached

        let mutation = reduce(state, .facadeLoadedProgramQueue([]))

        XCTAssertEqual(mutation.state.program.currentID, detached.id)
        XCTAssertEqual(mutation.state.program.currentDetachedItem, detached)
    }

    private func reduce(
        _ state: LiveRuntimeState = LiveRuntimeState(),
        _ action: LiveRuntimeAction
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(bridgeMode: .programQueueOwned)
        )
    }

    private func queueState(_ items: [ProgramItem]) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.program.items = items
        return state
    }

    private func programItem(_ title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "MEDIA", sourceURL: URL(fileURLWithPath: "/tmp/\(title).mp4"))
    }
}
