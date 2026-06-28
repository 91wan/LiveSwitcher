enum SupportRuntimeActionDispatcher {
    static func dispatch(
        action: LiveRuntimeAction,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        environment: LiveRuntimeEnvironment
    ) -> Bool {
        let bridgeMode = environment.bridgeMode

        switch action {
        case .supportEventRecorded(let event):
            guard LiveRuntimeReducer.isRuntimeOwned(.support, in: bridgeMode) else { return true }
            SupportRuntimeReducer.record(event: event, state: &state, effects: &effects)

        default:
            return false
        }

        return true
    }
}
