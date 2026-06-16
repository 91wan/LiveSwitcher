import XCTest
@testable import LiveSwitcher

final class PresentationQueryRuntimeStaleCallbackTests: XCTestCase {
    func testCompletedPresentationQueryIgnoresStaleRequestID() {
        let stale = UUID()
        let active = UUID()
        var state = activeState(active)

        let mutation = reduce(state, .presentationQueryCompleted(id: stale, result: result("Stale")))

        XCTAssertEqual(mutation.state.presentationQuery, state.presentationQuery)
    }

    func testCompletedPresentationQueryDoesNotClearNewerActiveRequest() {
        let stale = UUID()
        let active = UUID()
        let mutation = reduce(activeState(active), .presentationQueryCompleted(id: stale, result: result("Stale")))

        XCTAssertEqual(mutation.state.presentationQuery.activeRequestID, active)
    }

    func testCompletedPresentationQueryDoesNotOverwriteExistingResultForStaleID() {
        let stale = UUID()
        let active = UUID()
        var state = activeState(active)
        let existing = result("Existing")
        state.presentationQuery.latestCompletedRequestID = UUID()
        state.presentationQuery.latestResult = existing

        let mutation = reduce(state, .presentationQueryCompleted(id: stale, result: result("Stale")))

        XCTAssertEqual(mutation.state.presentationQuery.latestResult, existing)
    }

    func testFailedPresentationQueryIgnoresStaleRequestID() {
        let stale = UUID()
        let active = UUID()
        var state = activeState(active)

        let mutation = reduce(state, failureAction(stale))

        XCTAssertEqual(mutation.state.presentationQuery, state.presentationQuery)
    }

    func testFailedPresentationQueryDoesNotClearNewerActiveRequest() {
        let stale = UUID()
        let active = UUID()
        let mutation = reduce(activeState(active), failureAction(stale))

        XCTAssertEqual(mutation.state.presentationQuery.activeRequestID, active)
    }

    func testFailedPresentationQueryDoesNotOverwriteExistingFailureForStaleID() {
        let stale = UUID()
        let active = UUID()
        let existingID = UUID()
        var state = activeState(active)
        state.presentationQuery.latestFailure = failure(existingID, message: "existing")

        let mutation = reduce(state, failureAction(stale))

        XCTAssertEqual(mutation.state.presentationQuery.latestFailure, failure(existingID, message: "existing"))
    }

    func testNewRequestClearsPriorCompletedResult() {
        let oldID = UUID()
        var state = LiveRuntimeState()
        state.presentationQuery.latestCompletedRequestID = oldID
        state.presentationQuery.latestResult = result("Old")

        let mutation = reduce(state, .operatorRequestedPresentationQuery(id: UUID()))

        XCTAssertNil(mutation.state.presentationQuery.latestCompletedRequestID)
        XCTAssertNil(mutation.state.presentationQuery.latestResult)
    }

    func testNewRequestClearsPriorFailure() {
        var state = LiveRuntimeState()
        state.presentationQuery.latestFailure = failure(UUID(), message: "old")

        let mutation = reduce(state, .operatorRequestedPresentationQuery(id: UUID()))

        XCTAssertNil(mutation.state.presentationQuery.latestFailure)
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

    private func result(_ title: String) -> PresentationQueryResult {
        PresentationQueryResult(openFilePaths: ["/tmp/show/\(title).key"], windowNames: ["\(title).key"])
    }

    private func failureAction(_ id: UUID) -> LiveRuntimeAction {
        .presentationQueryFailed(id: id, action: "keynote.scan.windows", sanitizedMessage: "permissionDenied")
    }

    private func failure(_ id: UUID, message: String) -> PresentationQueryFailure {
        PresentationQueryFailure(id: id, action: "keynote.scan.windows", sanitizedMessage: message)
    }
}
