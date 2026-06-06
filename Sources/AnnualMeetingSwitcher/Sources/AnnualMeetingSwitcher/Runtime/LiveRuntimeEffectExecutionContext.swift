/// Carries effect execution dependencies that future callback-capable ports use to dispatch Runtime callback actions.
/// Do not bypass this by wiring callback actions directly through SwitcherViewModel closures.
struct LiveRuntimeEffectExecutionContext {
    let currentState: () -> LiveRuntimeState
    let dispatch: (LiveRuntimeAction) -> Void
}
