import XCTest
@testable import LiveSwitcher

final class ProgramQueueRuntimeCurrentSelectionTests: XCTestCase {
    func testRemoveProgramItemStillClearsCurrentQueuedSelection() {
        let current = programItem("Current")
        var state = queueState([current])
        state.program.currentID = current.id
        state.program.currentSwitchedAt = Date(timeIntervalSince1970: 10)

        let mutation = reduce(state, .operatorRemovedProgramItem(current.id))

        XCTAssertNil(mutation.state.program.currentID)
        XCTAssertNil(mutation.state.program.currentDetachedItem)
        XCTAssertNil(mutation.state.program.currentSwitchedAt)
    }

    func testFacadeLoadedProgramQueueStillClearsMissingCurrentQueuedSelection() {
        let current = programItem("Current")
        var state = queueState([current])
        state.program.currentID = current.id
        state.program.currentSwitchedAt = Date(timeIntervalSince1970: 10)

        let mutation = reduce(state, .facadeLoadedProgramQueue([]))

        XCTAssertNil(mutation.state.program.currentID)
        XCTAssertNil(mutation.state.program.currentDetachedItem)
        XCTAssertNil(mutation.state.program.currentSwitchedAt)
    }

    func testFacadeLoadedProgramQueueStillPreservesDetachedCurrentSelection() {
        let detached = programItem("Detached")
        var state = queueState([])
        state.program.currentID = detached.id
        state.program.currentDetachedItem = detached

        let mutation = reduce(state, .facadeLoadedProgramQueue([]))

        XCTAssertEqual(mutation.state.program.currentID, detached.id)
        XCTAssertEqual(mutation.state.program.currentDetachedItem, detached)
    }

    private func reduce(_ state: LiveRuntimeState, _ action: LiveRuntimeAction) -> LiveRuntimeMutation {
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
