import XCTest
@testable import LiveSwitcher

final class ProgramSelectionRuntimeStateTests: XCTestCase {
    func testProgramQueueOwnedDoesNotSelectProgram() {
        let item = programItem("Queued")
        var state = LiveRuntimeState()
        state.program.items = [item]

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedProgram(item.id),
            environment: .productionProgramQueueOwning(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertNil(mutation.state.program.currentID)
        XCTAssertNil(mutation.state.program.currentSwitchedAt)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testProgramSelectionOwnedSelectsQueuedProgram() {
        let item = programItem("Queued")
        var state = LiveRuntimeState()
        state.program.items = [item]

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedProgram(item.id),
            environment: .productionProgramSelectionOwning(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertEqual(mutation.state.program.currentID, item.id)
        XCTAssertNil(mutation.state.program.currentDetachedItem)
        XCTAssertEqual(mutation.state.program.currentSwitchedAt, Date(timeIntervalSince1970: 100))
    }

    func testProgramSelectionOwnedSelectsDetachedProgram() {
        let detached = programItem("Detached")
        var state = LiveRuntimeState()
        state.program.items = [programItem("Queued")]

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedDetachedProgram(detached),
            environment: .productionProgramSelectionOwning(now: Date(timeIntervalSince1970: 200))
        )

        XCTAssertEqual(mutation.state.program.currentID, detached.id)
        XCTAssertEqual(mutation.state.program.currentDetachedItem, detached)
        XCTAssertEqual(mutation.state.program.effectiveCurrentItem, detached)
        XCTAssertEqual(mutation.state.program.currentSwitchedAt, Date(timeIntervalSince1970: 200))
    }

    func testRemovingCurrentQueueItemClearsSelectionAndSwitchedAt() {
        let item = programItem("Current")
        var state = LiveRuntimeState()
        state.program.items = [item]
        state.program.currentID = item.id
        state.program.currentSwitchedAt = Date(timeIntervalSince1970: 50)

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorRemovedProgramItem(item.id),
            environment: .productionProgramSelectionOwning()
        )

        XCTAssertTrue(mutation.state.program.items.isEmpty)
        XCTAssertNil(mutation.state.program.currentID)
        XCTAssertNil(mutation.state.program.currentDetachedItem)
        XCTAssertNil(mutation.state.program.currentSwitchedAt)
    }

    func testReplacingQueueClearsMissingQueuedSelectionAndSwitchedAt() {
        let current = programItem("Current")
        var state = LiveRuntimeState()
        state.program.items = [current]
        state.program.currentID = current.id
        state.program.currentSwitchedAt = Date(timeIntervalSince1970: 50)

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .facadeLoadedProgramQueue([]),
            environment: .productionProgramSelectionOwning()
        )

        XCTAssertTrue(mutation.state.program.items.isEmpty)
        XCTAssertNil(mutation.state.program.currentID)
        XCTAssertNil(mutation.state.program.currentDetachedItem)
        XCTAssertNil(mutation.state.program.currentSwitchedAt)
    }

    func testReplacingQueuePreservesDetachedSelection() {
        let detached = programItem("Detached")
        var state = LiveRuntimeState()
        state.program.currentID = detached.id
        state.program.currentDetachedItem = detached
        state.program.currentSwitchedAt = Date(timeIntervalSince1970: 50)

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .facadeLoadedProgramQueue([]),
            environment: .productionProgramSelectionOwning()
        )

        XCTAssertEqual(mutation.state.program.currentID, detached.id)
        XCTAssertEqual(mutation.state.program.currentDetachedItem, detached)
        XCTAssertEqual(mutation.state.program.currentSwitchedAt, Date(timeIntervalSince1970: 50))
    }

    private func programItem(_ title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "MEDIA", sourceURL: URL(fileURLWithPath: "/tmp/\(title).mp4"))
    }
}
