import Foundation

struct LiveRuntimeMutation: Equatable {
    var state: LiveRuntimeState
    var effects: [LiveRuntimeEffect]
}

enum LiveRuntimeReducer {
    static func reduce(
        state: LiveRuntimeState,
        action: LiveRuntimeAction,
        environment: LiveRuntimeEnvironment
    ) -> LiveRuntimeMutation {
        var state = state
        var effects: [LiveRuntimeEffect] = []

        dispatch(
            action: action,
            state: &state,
            effects: &effects,
            environment: environment
        )

        return LiveRuntimeMutation(
            state: state,
            effects: effects.filter { isEffectAllowed($0, in: environment.bridgeMode) }
        )
    }

    private static func dispatch(
        action: LiveRuntimeAction,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        environment: LiveRuntimeEnvironment
    ) {
        if ProgramRuntimeActionDispatcher.dispatch(
            action: action,
            state: &state,
            effects: &effects,
            environment: environment
        ) { return }

        if MediaRuntimeActionDispatcher.dispatch(
            action: action,
            state: &state,
            effects: &effects,
            environment: environment
        ) { return }

        if AudioRuntimeActionDispatcher.dispatch(
            action: action,
            state: &state,
            effects: &effects,
            environment: environment
        ) { return }

        if BGMRuntimeActionDispatcher.dispatch(
            action: action,
            state: &state,
            effects: &effects,
            environment: environment
        ) { return }

        if PanicProjectionRuntimeActionDispatcher.dispatch(
            action: action,
            state: &state,
            effects: &effects,
            environment: environment
        ) { return }

        if PreferenceRuntimeActionDispatcher.dispatch(
            action: action,
            state: &state,
            effects: &effects,
            environment: environment
        ) { return }

        if AutomationRuntimeActionDispatcher.dispatch(
            action: action,
            state: &state,
            effects: &effects,
            environment: environment
        ) { return }

        _ = SupportRuntimeActionDispatcher.dispatch(
            action: action,
            state: &state,
            effects: &effects,
            environment: environment
        )
    }

    private static func isEffectAllowed(_ effect: LiveRuntimeEffect, in bridgeMode: LiveRuntimeBridgeMode) -> Bool {
        if bridgeMode == .fullRuntime { return true }
        if bridgeMode == .recordingOnly { return false }

        return bridgeMode.owns(effect.requiredBridgeDomain)
    }

    static func isRuntimeOwned(_ domain: LiveRuntimeDomain, in bridgeMode: LiveRuntimeBridgeMode) -> Bool {
        bridgeMode.owns(domain)
    }

    static func canGenerateReducerSupport(in bridgeMode: LiveRuntimeBridgeMode) -> Bool {
        bridgeMode == .fullRuntime
    }
}
