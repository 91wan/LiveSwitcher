import Foundation

enum PresentationQueryRuntimeReducer {
    static func request(
        id: UUID,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        state.presentationQuery.activeRequestID = id
        state.presentationQuery.latestCompletedRequestID = nil
        state.presentationQuery.latestResult = nil
        state.presentationQuery.latestFailure = nil
        effects.append(.scanPresentationQuery(id: id))
    }

    static func complete(
        id: UUID,
        result: PresentationQueryResult,
        state: inout LiveRuntimeState
    ) {
        guard state.presentationQuery.activeRequestID == id else { return }

        state.presentationQuery.activeRequestID = nil
        state.presentationQuery.latestCompletedRequestID = id
        state.presentationQuery.latestResult = result
        state.presentationQuery.latestFailure = nil
    }

    static func fail(
        id: UUID,
        action: String,
        sanitizedMessage: String,
        state: inout LiveRuntimeState
    ) {
        guard state.presentationQuery.activeRequestID == id else { return }

        state.presentationQuery.activeRequestID = nil
        state.presentationQuery.latestCompletedRequestID = nil
        state.presentationQuery.latestResult = nil
        state.presentationQuery.latestFailure = PresentationQueryFailure(
            id: id,
            action: action,
            sanitizedMessage: sanitizedMessage
        )
    }

    static func consumeResult(
        id: UUID,
        state: inout LiveRuntimeState
    ) {
        state.presentationQuery.markConsumed(id)
    }
}
