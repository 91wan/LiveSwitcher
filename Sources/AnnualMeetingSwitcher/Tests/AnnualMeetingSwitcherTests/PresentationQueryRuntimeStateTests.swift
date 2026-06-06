import XCTest
@testable import LiveSwitcher

final class PresentationQueryRuntimeStateTests: XCTestCase {
    func testPresentationQueryStateDefaultsToIdle() {
        let state = LiveRuntimeState().presentationQuery

        XCTAssertNil(state.activeRequestID)
        XCTAssertNil(state.latestCompletedRequestID)
        XCTAssertNil(state.latestResult)
        XCTAssertNil(state.latestFailure)
        XCTAssertTrue(state.consumedRequestIDs.isEmpty)
    }

    func testPresentationQueryRequestMarksActiveRequest() {
        let id = UUID()
        let mutation = reduce(.operatorRequestedPresentationQuery(id: id))

        XCTAssertEqual(mutation.state.presentationQuery.activeRequestID, id)
    }

    func testPresentationQueryRequestClearsPreviousOutcomeButPreservesConsumedIDs() {
        let oldID = UUID()
        let newID = UUID()
        var state = LiveRuntimeState()
        state.presentationQuery.latestCompletedRequestID = oldID
        state.presentationQuery.latestResult = PresentationQueryResult(openFilePaths: ["/tmp/show/Old.key"], windowNames: [])
        state.presentationQuery.latestFailure = PresentationQueryFailure(
            id: oldID,
            action: "keynote.scan.windows",
            sanitizedMessage: "oldFailure"
        )
        state.presentationQuery.markConsumed(oldID)

        let mutation = reduce(state, .operatorRequestedPresentationQuery(id: newID))

        XCTAssertEqual(mutation.state.presentationQuery.activeRequestID, newID)
        XCTAssertNil(mutation.state.presentationQuery.latestCompletedRequestID)
        XCTAssertNil(mutation.state.presentationQuery.latestResult)
        XCTAssertNil(mutation.state.presentationQuery.latestFailure)
        XCTAssertTrue(mutation.state.presentationQuery.hasConsumed(oldID))
    }

    func testPresentationQueryCompletionStoresResultAndClearsActiveRequest() {
        let id = UUID()
        var state = LiveRuntimeState()
        state.presentationQuery.activeRequestID = id
        let result = PresentationQueryResult(openFilePaths: ["/tmp/show/Opening.key"], windowNames: ["Ignored.key"])

        let mutation = reduce(state, .presentationQueryCompleted(id: id, result: result))

        XCTAssertNil(mutation.state.presentationQuery.activeRequestID)
        XCTAssertEqual(mutation.state.presentationQuery.latestCompletedRequestID, id)
        XCTAssertEqual(mutation.state.presentationQuery.latestResult, result)
    }

    func testPresentationQueryFailureStoresFailureAndClearsActiveRequest() {
        let id = UUID()
        var state = LiveRuntimeState()
        state.presentationQuery.activeRequestID = id

        let mutation = reduce(state, .presentationQueryFailed(id: id, action: "keynote.scan.windows", sanitizedMessage: "permissionDenied"))

        XCTAssertNil(mutation.state.presentationQuery.activeRequestID)
        XCTAssertEqual(mutation.state.presentationQuery.latestFailure, PresentationQueryFailure(
            id: id,
            action: "keynote.scan.windows",
            sanitizedMessage: "permissionDenied"
        ))
    }

    func testPresentationQueryConsumedMarksRequestConsumed() {
        let id = UUID()
        let mutation = reduce(.presentationQueryResultConsumed(id: id))

        XCTAssertTrue(mutation.state.presentationQuery.hasConsumed(id))
    }

    func testPresentationQueryConsumedClearsMatchingCompletedResultAndFailure() {
        let id = UUID()
        var state = LiveRuntimeState()
        state.presentationQuery.latestCompletedRequestID = id
        state.presentationQuery.latestResult = PresentationQueryResult(openFilePaths: ["/tmp/show/Opening.key"], windowNames: [])
        state.presentationQuery.latestFailure = PresentationQueryFailure(
            id: id,
            action: "keynote.scan.windows",
            sanitizedMessage: "permissionDenied"
        )

        let mutation = reduce(state, .presentationQueryResultConsumed(id: id))

        XCTAssertNil(mutation.state.presentationQuery.latestCompletedRequestID)
        XCTAssertNil(mutation.state.presentationQuery.latestResult)
        XCTAssertNil(mutation.state.presentationQuery.latestFailure)
        XCTAssertTrue(mutation.state.presentationQuery.hasConsumed(id))
    }

    func testPresentationQueryConsumedIDsAreCappedToRecentTwenty() {
        var state = LiveRuntimeState()
        let ids = (0..<25).map { _ in UUID() }
        ids.forEach { state.presentationQuery.markConsumed($0) }

        XCTAssertEqual(state.presentationQuery.consumedRequestIDs.count, 20)
        XCTAssertFalse(state.presentationQuery.hasConsumed(ids[0]))
        XCTAssertTrue(state.presentationQuery.hasConsumed(ids[24]))
    }

    func testPresentationQueryConsumedLeavesStateIdleForMatchingOutcome() {
        let id = UUID()
        var state = LiveRuntimeState()
        state.presentationQuery.activeRequestID = nil
        state.presentationQuery.latestCompletedRequestID = id
        state.presentationQuery.latestResult = .empty

        let mutation = reduce(state, .presentationQueryResultConsumed(id: id))

        XCTAssertNil(mutation.state.presentationQuery.activeRequestID)
        XCTAssertNil(mutation.state.presentationQuery.latestCompletedRequestID)
        XCTAssertNil(mutation.state.presentationQuery.latestResult)
        XCTAssertNil(mutation.state.presentationQuery.latestFailure)
    }

    func testPresentationQueryCompletionDoesNotMutateProgramQueue() {
        let id = UUID()
        var state = LiveRuntimeState()
        state.presentationQuery.activeRequestID = id
        let existing = ProgramItem(title: "Existing", subtitle: "KEY")
        state.program.items = [existing]
        let result = PresentationQueryResult(openFilePaths: ["/tmp/show/New.key"], windowNames: [])

        let mutation = reduce(state, .presentationQueryCompleted(id: id, result: result))

        XCTAssertEqual(mutation.state.program.items, [existing])
    }

    func testPresentationQueryFailureDoesNotWriteSupportInPresentationQueryOwnedMode() {
        let id = UUID()
        var state = LiveRuntimeState()
        state.presentationQuery.activeRequestID = id

        let mutation = reduce(state, .presentationQueryFailed(id: id, action: "keynote.scan.windows", sanitizedMessage: "failed"))

        XCTAssertTrue(mutation.state.support.events.isEmpty)
        XCTAssertEqual(mutation.effects, [])
    }

    private func reduce(_ action: LiveRuntimeAction) -> LiveRuntimeMutation {
        reduce(LiveRuntimeState(), action)
    }

    private func reduce(_ state: LiveRuntimeState, _ action: LiveRuntimeAction) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(bridgeMode: .presentationQueryOwned)
        )
    }
}
