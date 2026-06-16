import XCTest
@testable import LiveSwitcher

final class PresentationQueryRuntimeConsumeTests: XCTestCase {
    func testConsumedRequestIDsDoNotDuplicateIDs() {
        let id = UUID()
        var state = reduce(.presentationQueryResultConsumed(id: id)).state

        state = reduce(state, .presentationQueryResultConsumed(id: id)).state

        XCTAssertEqual(state.presentationQuery.consumedRequestIDs, [id])
    }

    func testConsumedRequestIDsTrimToLimit() {
        let ids = (0..<25).map { _ in UUID() }
        var state = LiveRuntimeState()

        for id in ids {
            state = reduce(state, .presentationQueryResultConsumed(id: id)).state
        }

        XCTAssertEqual(state.presentationQuery.consumedRequestIDs.count, PresentationQueryRuntimeState.consumedRequestLimit)
        XCTAssertFalse(state.presentationQuery.hasConsumed(ids[0]))
        XCTAssertTrue(state.presentationQuery.hasConsumed(ids[24]))
    }

    func testConsumeResultClearsLatestCompletedRequestWhenMatching() {
        let id = UUID()
        var state = completedState(id: id)

        let mutation = reduce(state, .presentationQueryResultConsumed(id: id))

        XCTAssertNil(mutation.state.presentationQuery.latestCompletedRequestID)
        XCTAssertNil(mutation.state.presentationQuery.latestResult)
    }

    func testConsumeResultClearsLatestFailureWhenMatching() {
        let id = UUID()
        var state = LiveRuntimeState()
        state.presentationQuery.latestFailure = failure(id)

        let mutation = reduce(state, .presentationQueryResultConsumed(id: id))

        XCTAssertNil(mutation.state.presentationQuery.latestFailure)
    }

    func testConsumeResultDoesNotClearUnrelatedLatestResult() {
        let resultID = UUID()
        var state = completedState(id: resultID)

        let mutation = reduce(state, .presentationQueryResultConsumed(id: UUID()))

        XCTAssertEqual(mutation.state.presentationQuery.latestCompletedRequestID, resultID)
        XCTAssertEqual(mutation.state.presentationQuery.latestResult, result)
    }

    func testConsumeResultDoesNotClearUnrelatedLatestFailure() {
        let failureID = UUID()
        var state = LiveRuntimeState()
        state.presentationQuery.latestFailure = failure(failureID)

        let mutation = reduce(state, .presentationQueryResultConsumed(id: UUID()))

        XCTAssertEqual(mutation.state.presentationQuery.latestFailure, failure(failureID))
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

    private func completedState(id: UUID) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.presentationQuery.latestCompletedRequestID = id
        state.presentationQuery.latestResult = result
        return state
    }

    private func failure(_ id: UUID) -> PresentationQueryFailure {
        PresentationQueryFailure(id: id, action: "keynote.scan.windows", sanitizedMessage: "permissionDenied")
    }
}
