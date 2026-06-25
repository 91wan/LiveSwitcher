import XCTest
@testable import LiveSwitcher

final class ProgramQueueRuntimeMutationPolicyTests: XCTestCase {
    func testAppendProgramItemsPreservesOrder() {
        let first = programItem("First")
        let second = programItem("Second")
        var state = ProgramRuntimeState()

        state.appendProgramItems([first, second])

        XCTAssertEqual(state.items, [first, second])
    }

    func testRemoveProgramItemClearsCurrentIDWhenCurrentRemoved() {
        let item = programItem("Current")
        var state = ProgramRuntimeState(items: [item], currentID: item.id)

        state.removeProgramItem(id: item.id)

        XCTAssertTrue(state.items.isEmpty)
        XCTAssertNil(state.currentID)
    }

    func testRemoveProgramItemPreservesDetachedCurrentItem() {
        let queued = programItem("Queued")
        let detached = programItem("Detached")
        var state = ProgramRuntimeState(
            items: [queued],
            currentID: detached.id,
            currentDetachedItem: detached
        )

        state.removeProgramItem(id: queued.id)

        XCTAssertEqual(state.currentID, detached.id)
        XCTAssertEqual(state.currentDetachedItem, detached)
    }

    func testMoveProgramItemsMatchesExpectedSwiftUIMoveSemantics() {
        let first = programItem("First")
        let second = programItem("Second")
        let third = programItem("Third")
        var state = ProgramRuntimeState(items: [first, second, third])

        state.moveProgramItems(fromOffsets: [0], toOffset: 3)

        XCTAssertEqual(state.items.map(\.id), [second.id, third.id, first.id])
    }

    func testMoveProgramItemsIgnoresInvalidIndices() {
        let item = programItem("Only")
        var state = ProgramRuntimeState(items: [item])

        state.moveProgramItems(fromOffsets: [5], toOffset: 1)

        XCTAssertEqual(state.items, [item])
    }

    func testMoveProgramItemsHandlesDuplicateOffsets() {
        let first = programItem("First")
        let second = programItem("Second")
        let third = programItem("Third")
        var state = ProgramRuntimeState(items: [first, second, third])

        state.moveProgramItems(fromOffsets: [0, 0], toOffset: 3)

        XCTAssertEqual(state.items.map(\.id), [second.id, third.id, first.id])
    }

    func testUpdateProgramItemScheduleUpdatesExistingItem() {
        let item = programItem("Scheduled")
        let start = Date(timeIntervalSince1970: 100)
        var state = ProgramRuntimeState(items: [item])

        state.updateProgramItemSchedule(id: item.id, scheduledStartAt: start, scheduledDuration: 45)

        XCTAssertEqual(state.items.first?.scheduledStartAt, start)
        XCTAssertEqual(state.items.first?.scheduledDuration, 45)
    }

    func testUpdateProgramItemScheduleNoopsForMissingItem() {
        let item = programItem("Scheduled")
        var state = ProgramRuntimeState(items: [item])

        state.updateProgramItemSchedule(id: UUID(), scheduledStartAt: Date(), scheduledDuration: 45)

        XCTAssertEqual(state.items, [item])
    }

    func testAppendAgendaMarkerUsesInputWithoutImplicitStart() {
        let start = Date(timeIntervalSince1970: 100)
        var item = programItem("Video")
        item.scheduledStartAt = start
        item.scheduledDuration = 60
        var state = ProgramRuntimeState(items: [item])

        state.appendAgendaMarker(input: AgendaMarkerInput(title: "茶歇", scheduledStartAt: nil, duration: 15 * 60))

        XCTAssertEqual(state.items.last?.title, "茶歇")
        XCTAssertNil(state.items.last?.scheduledStartAt)
        XCTAssertEqual(state.items.last?.scheduledDuration, 15 * 60)
    }

    func testAppendAgendaMarkerPreservesExplicitStartWhenProvided() {
        let start = Date(timeIntervalSince1970: 100)
        var state = ProgramRuntimeState(items: [programItem("Unscheduled")])

        state.appendAgendaMarker(input: AgendaMarkerInput(title: "提醒", scheduledStartAt: start, duration: 10 * 60))

        XCTAssertEqual(state.items.last?.scheduledStartAt, start)
        XCTAssertEqual(state.items.last?.scheduledDuration, 10 * 60)
    }

    func testUpdateAgendaMarkerNoopsForNormalProgram() {
        let item = programItem("Program")
        var state = ProgramRuntimeState(items: [item])

        state.updateAgendaMarker(
            id: item.id,
            input: AgendaMarkerInput(title: "转场", scheduledStartAt: Date(), duration: 20 * 60)
        )

        XCTAssertEqual(state.items, [item])
    }

    func testReplaceProgramQueueClearsMissingCurrentID() {
        let current = programItem("Current")
        var state = ProgramRuntimeState(items: [current], currentID: current.id)

        state.replaceProgramQueueFromFacade([])

        XCTAssertTrue(state.items.isEmpty)
        XCTAssertNil(state.currentID)
    }

    func testReplaceProgramQueuePreservesDetachedCurrentID() {
        let detached = programItem("Detached")
        var state = ProgramRuntimeState(
            items: [],
            currentID: detached.id,
            currentDetachedItem: detached
        )

        state.replaceProgramQueueFromFacade([])

        XCTAssertEqual(state.currentID, detached.id)
        XCTAssertEqual(state.currentDetachedItem, detached)
    }

    private func programItem(_ title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "MEDIA", sourceURL: URL(fileURLWithPath: "/tmp/\(title).mp4"))
    }
}
