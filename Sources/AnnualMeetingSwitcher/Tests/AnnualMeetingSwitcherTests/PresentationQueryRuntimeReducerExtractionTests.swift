import XCTest
@testable import LiveSwitcher

final class PresentationQueryRuntimeReducerExtractionTests: XCTestCase {
    func testRequestStartsActiveQueryClearsPriorResultAndFailureAndEmitsScan() {
        let oldID = UUID()
        let id = UUID()
        var state = completedState(id: oldID, title: "Old")
        state.presentationQuery.latestFailure = failure(oldID, message: "old failure")

        let mutation = reduce(state, .operatorRequestedPresentationQuery(id: id))

        XCTAssertEqual(mutation.state.presentationQuery.activeRequestID, id)
        XCTAssertNil(mutation.state.presentationQuery.latestCompletedRequestID)
        XCTAssertNil(mutation.state.presentationQuery.latestResult)
        XCTAssertNil(mutation.state.presentationQuery.latestFailure)
        XCTAssertEqual(mutation.effects, [.scanPresentationQuery(id: id)])
    }

    func testCompletedQueryAcceptsOnlyActiveRequestAndClearsFailure() {
        let id = UUID()
        var state = activeState(id)
        state.presentationQuery.latestFailure = failure(id, message: "old failure")

        let mutation = reduce(state, .presentationQueryCompleted(id: id, result: result("Opening")))

        XCTAssertNil(mutation.state.presentationQuery.activeRequestID)
        XCTAssertEqual(mutation.state.presentationQuery.latestCompletedRequestID, id)
        XCTAssertEqual(mutation.state.presentationQuery.latestResult, result("Opening"))
        XCTAssertNil(mutation.state.presentationQuery.latestFailure)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testFailedQueryAcceptsOnlyActiveRequestAndClearsResult() {
        let id = UUID()
        var state = activeState(id)
        state.presentationQuery.latestCompletedRequestID = UUID()
        state.presentationQuery.latestResult = result("Old")

        let mutation = reduce(state, failureAction(id, message: "permissionDenied"))

        XCTAssertNil(mutation.state.presentationQuery.activeRequestID)
        XCTAssertNil(mutation.state.presentationQuery.latestCompletedRequestID)
        XCTAssertNil(mutation.state.presentationQuery.latestResult)
        XCTAssertEqual(mutation.state.presentationQuery.latestFailure, failure(id, message: "permissionDenied"))
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testStaleSuccessAndFailureDoNotChangeCurrentQueryState() {
        let active = UUID()
        let stale = UUID()
        var state = activeState(active)
        state.presentationQuery.latestCompletedRequestID = UUID()
        state.presentationQuery.latestResult = result("Existing")
        state.presentationQuery.latestFailure = failure(UUID(), message: "existing")

        let staleSuccess = reduce(state, .presentationQueryCompleted(id: stale, result: result("Stale")))
        XCTAssertEqual(staleSuccess.state.presentationQuery, state.presentationQuery)

        let staleFailure = reduce(state, failureAction(stale, message: "stale"))
        XCTAssertEqual(staleFailure.state.presentationQuery, state.presentationQuery)
    }

    func testConsumeResultDeduplicatesTrimsAndClearsMatchingLatestState() {
        let first = UUID()
        var state = reduce(.presentationQueryResultConsumed(id: first)).state
        state = reduce(state, .presentationQueryResultConsumed(id: first)).state
        XCTAssertEqual(state.presentationQuery.consumedRequestIDs, [first])

        let ids = (0..<25).map { _ in UUID() }
        for id in ids {
            state = reduce(state, .presentationQueryResultConsumed(id: id)).state
        }
        XCTAssertEqual(state.presentationQuery.consumedRequestIDs.count, PresentationQueryRuntimeState.consumedRequestLimit)
        XCTAssertFalse(state.presentationQuery.hasConsumed(first))
        XCTAssertFalse(state.presentationQuery.hasConsumed(ids[0]))
        XCTAssertTrue(state.presentationQuery.hasConsumed(ids[24]))

        let resultID = UUID()
        let consumedResult = reduce(completedState(id: resultID, title: "Result"), .presentationQueryResultConsumed(id: resultID))
        XCTAssertNil(consumedResult.state.presentationQuery.latestCompletedRequestID)
        XCTAssertNil(consumedResult.state.presentationQuery.latestResult)

        let failureID = UUID()
        var failed = LiveRuntimeState()
        failed.presentationQuery.latestFailure = failure(failureID, message: "denied")
        let consumedFailure = reduce(failed, .presentationQueryResultConsumed(id: failureID))
        XCTAssertNil(consumedFailure.state.presentationQuery.latestFailure)
    }

    func testPresentationQueryActionsNoopWhenBridgeDoesNotOwnQueryDomain() {
        let state = LiveRuntimeState()
        let id = UUID()

        let mutation = reduce(
            state,
            .operatorRequestedPresentationQuery(id: id),
            environment: .recordingOnlyForTests()
        )

        XCTAssertEqual(mutation.state, state)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    private func reduce(_ action: LiveRuntimeAction) -> LiveRuntimeMutation {
        reduce(LiveRuntimeState(), action)
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction,
        environment: LiveRuntimeEnvironment = .productionPresentationQueryOwning()
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(state: state, action: action, environment: environment)
    }

    private func activeState(_ id: UUID) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.presentationQuery.activeRequestID = id
        return state
    }

    private func completedState(id: UUID, title: String) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.presentationQuery.latestCompletedRequestID = id
        state.presentationQuery.latestResult = result(title)
        return state
    }

    private func result(_ title: String) -> PresentationQueryResult {
        PresentationQueryResult(openFilePaths: ["/tmp/show/\(title).key"], windowNames: ["\(title).key"])
    }

    private func failureAction(_ id: UUID, message: String) -> LiveRuntimeAction {
        .presentationQueryFailed(id: id, action: "keynote.scan.windows", sanitizedMessage: message)
    }

    private func failure(_ id: UUID, message: String) -> PresentationQueryFailure {
        PresentationQueryFailure(id: id, action: "keynote.scan.windows", sanitizedMessage: message)
    }
}
