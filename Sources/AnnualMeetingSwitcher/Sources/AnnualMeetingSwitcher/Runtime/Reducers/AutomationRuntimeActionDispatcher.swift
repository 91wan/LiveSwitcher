enum AutomationRuntimeActionDispatcher {
    static func dispatch(
        action: LiveRuntimeAction,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        environment: LiveRuntimeEnvironment
    ) -> Bool {
        let bridgeMode = environment.bridgeMode

        switch action {
        case .automationScriptRequested(let script, let action):
            guard LiveRuntimeReducer.isRuntimeOwned(.automationCommand, in: bridgeMode) else { return true }
            AutomationCommandRuntimeReducer.requestScript(
                script: script,
                action: action,
                effects: &effects
            )

        case .automationFailed(let action, let sanitizedMessage):
            guard LiveRuntimeReducer.isRuntimeOwned(.automationNotice, in: bridgeMode) else { return true }
            AutomationNoticeRuntimeReducer.request(
                action: action,
                state: &state,
                effects: &effects,
                now: environment.now
            )
            if LiveRuntimeReducer.canGenerateReducerSupport(in: bridgeMode) {
                SupportRuntimeReducer.record(
                    kind: .appleScriptFailed,
                    detail: "action=\(action),error=\(sanitizedMessage)",
                    at: environment.now,
                    state: &state
                )
            }

        case .automationNoticeRequested(let action):
            guard LiveRuntimeReducer.isRuntimeOwned(.automationNotice, in: bridgeMode) else { return true }
            AutomationNoticeRuntimeReducer.request(
                action: action,
                state: &state,
                effects: &effects,
                now: environment.now
            )

        case .automationNoticeExpired(let id):
            guard LiveRuntimeReducer.isRuntimeOwned(.automationNotice, in: bridgeMode) else { return true }
            AutomationNoticeRuntimeReducer.expire(id: id, state: &state)

        case .automationNoticeDismissed:
            guard LiveRuntimeReducer.isRuntimeOwned(.automationNotice, in: bridgeMode) else { return true }
            AutomationNoticeRuntimeReducer.dismiss(state: &state)

        case .operatorRequestedPresentationQuery(let id):
            guard LiveRuntimeReducer.isRuntimeOwned(.presentationQuery, in: bridgeMode) else { return true }
            PresentationQueryRuntimeReducer.request(id: id, state: &state, effects: &effects)

        case .presentationQueryCompleted(let id, let result):
            guard LiveRuntimeReducer.isRuntimeOwned(.presentationQuery, in: bridgeMode) else { return true }
            PresentationQueryRuntimeReducer.complete(id: id, result: result, state: &state)

        case .presentationQueryFailed(let id, let action, let sanitizedMessage):
            guard LiveRuntimeReducer.isRuntimeOwned(.presentationQuery, in: bridgeMode) else { return true }
            PresentationQueryRuntimeReducer.fail(
                id: id,
                action: action,
                sanitizedMessage: sanitizedMessage,
                state: &state
            )

        case .presentationQueryResultConsumed(let id):
            guard LiveRuntimeReducer.isRuntimeOwned(.presentationQuery, in: bridgeMode) else { return true }
            PresentationQueryRuntimeReducer.consumeResult(id: id, state: &state)

        default:
            return false
        }

        return true
    }
}
