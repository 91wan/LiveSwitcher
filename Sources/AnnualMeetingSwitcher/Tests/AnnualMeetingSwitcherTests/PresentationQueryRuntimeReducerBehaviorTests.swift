import XCTest
@testable import LiveSwitcher

final class PresentationQueryRuntimeReducerBehaviorTests: XCTestCase {
    func testRequestPresentationQuerySetsActiveRequestID() {
        let id = UUID()
        let mutation = reduce(.operatorRequestedPresentationQuery(id: id))

        XCTAssertEqual(mutation.state.presentationQuery.activeRequestID, id)
    }

    func testRequestPresentationQueryClearsPreviousCompletedID() {
        let id = UUID()
        var state = completedState()

        let mutation = reduce(state, .operatorRequestedPresentationQuery(id: id))

        XCTAssertNil(mutation.state.presentationQuery.latestCompletedRequestID)
    }

    func testRequestPresentationQueryClearsPreviousResult() {
        let id = UUID()
        var state = completedState()

        let mutation = reduce(state, .operatorRequestedPresentationQuery(id: id))

        XCTAssertNil(mutation.state.presentationQuery.latestResult)
    }

    func testRequestPresentationQueryClearsPreviousFailure() {
        let id = UUID()
        var state = failedState()

        let mutation = reduce(state, .operatorRequestedPresentationQuery(id: id))

        XCTAssertNil(mutation.state.presentationQuery.latestFailure)
    }

    func testRequestPresentationQueryEmitsScanEffect() {
        let id = UUID()
        let mutation = reduce(.operatorRequestedPresentationQuery(id: id))

        XCTAssertEqual(mutation.effects, [.scanPresentationQuery(id: id)])
    }

    func testCompletedPresentationQueryClearsActiveRequest() {
        let id = UUID()
        let mutation = reduce(activeState(id), .presentationQueryCompleted(id: id, result: result))

        XCTAssertNil(mutation.state.presentationQuery.activeRequestID)
    }

    func testCompletedPresentationQueryStoresResult() {
        let id = UUID()
        let mutation = reduce(activeState(id), .presentationQueryCompleted(id: id, result: result))

        XCTAssertEqual(mutation.state.presentationQuery.latestResult, result)
    }

    func testCompletedPresentationQueryStoresCompletedID() {
        let id = UUID()
        let mutation = reduce(activeState(id), .presentationQueryCompleted(id: id, result: result))

        XCTAssertEqual(mutation.state.presentationQuery.latestCompletedRequestID, id)
    }

    func testCompletedPresentationQueryClearsFailure() {
        let id = UUID()
        var state = activeState(id)
        state.presentationQuery.latestFailure = failure(id: UUID())

        let mutation = reduce(state, .presentationQueryCompleted(id: id, result: result))

        XCTAssertNil(mutation.state.presentationQuery.latestFailure)
    }

    func testFailedPresentationQueryClearsActiveRequest() {
        let id = UUID()
        let mutation = reduce(activeState(id), failedAction(id))

        XCTAssertNil(mutation.state.presentationQuery.activeRequestID)
    }

    func testFailedPresentationQueryClearsResult() {
        let id = UUID()
        var state = activeState(id)
        state.presentationQuery.latestResult = result

        let mutation = reduce(state, failedAction(id))

        XCTAssertNil(mutation.state.presentationQuery.latestResult)
    }

    func testFailedPresentationQueryClearsCompletedID() {
        let id = UUID()
        var state = activeState(id)
        state.presentationQuery.latestCompletedRequestID = UUID()

        let mutation = reduce(state, failedAction(id))

        XCTAssertNil(mutation.state.presentationQuery.latestCompletedRequestID)
    }

    func testFailedPresentationQueryStoresFailure() {
        let id = UUID()
        let mutation = reduce(activeState(id), failedAction(id))

        XCTAssertEqual(mutation.state.presentationQuery.latestFailure, failure(id: id))
    }

    func testFailedPresentationQueryStoresSanitizedMessage() {
        let id = UUID()
        let mutation = reduce(activeState(id), failedAction(id))

        XCTAssertEqual(mutation.state.presentationQuery.latestFailure?.sanitizedMessage, "permissionDenied")
    }

    func testConsumedPresentationQueryMarksIDConsumed() {
        let id = UUID()
        let mutation = reduce(.presentationQueryResultConsumed(id: id))

        XCTAssertTrue(mutation.state.presentationQuery.hasConsumed(id))
    }

    func testConsumedPresentationQueryClearsMatchingLatestResult() {
        let id = UUID()
        var state = completedState(id: id)

        let mutation = reduce(state, .presentationQueryResultConsumed(id: id))

        XCTAssertNil(mutation.state.presentationQuery.latestCompletedRequestID)
        XCTAssertNil(mutation.state.presentationQuery.latestResult)
    }

    func testConsumedPresentationQueryClearsMatchingLatestFailure() {
        let id = UUID()
        var state = LiveRuntimeState()
        state.presentationQuery.latestFailure = failure(id: id)

        let mutation = reduce(state, .presentationQueryResultConsumed(id: id))

        XCTAssertNil(mutation.state.presentationQuery.latestFailure)
    }

    private var result: PresentationQueryResult {
        PresentationQueryResult(openFilePaths: ["/tmp/show/Opening.key"], windowNames: ["Opening.key"])
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

    private func activeState(_ id: UUID) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.presentationQuery.activeRequestID = id
        return state
    }

    private func completedState(id: UUID = UUID()) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.presentationQuery.latestCompletedRequestID = id
        state.presentationQuery.latestResult = result
        return state
    }

    private func failedState(id: UUID = UUID()) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.presentationQuery.latestFailure = failure(id: id)
        return state
    }

    private func failedAction(_ id: UUID) -> LiveRuntimeAction {
        .presentationQueryFailed(id: id, action: "keynote.scan.windows", sanitizedMessage: "permissionDenied")
    }

    private func failure(id: UUID) -> PresentationQueryFailure {
        PresentationQueryFailure(id: id, action: "keynote.scan.windows", sanitizedMessage: "permissionDenied")
    }
}
