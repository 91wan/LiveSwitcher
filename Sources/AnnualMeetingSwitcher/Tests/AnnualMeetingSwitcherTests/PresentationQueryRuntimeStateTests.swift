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

        XCTAssertTrue(mutation.state.presentationQuery.consumedRequestIDs.contains(id))
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
