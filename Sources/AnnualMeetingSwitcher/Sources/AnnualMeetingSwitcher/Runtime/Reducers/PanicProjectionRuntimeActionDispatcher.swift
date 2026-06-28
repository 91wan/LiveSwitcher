enum PanicProjectionRuntimeActionDispatcher {
    static func dispatch(
        action: LiveRuntimeAction,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        environment: LiveRuntimeEnvironment
    ) -> Bool {
        let bridgeMode = environment.bridgeMode

        switch action {
        case .operatorToggledPanic:
            guard LiveRuntimeReducer.isRuntimeOwned(.panic, in: bridgeMode) else { return true }
            PanicRuntimeReducer.setPanic(
                !state.panic.isActive,
                state: &state,
                effects: &effects,
                liveAudioFadeDuration: environment.liveAudioFadeDuration,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorSetPanic(let isActive):
            guard LiveRuntimeReducer.isRuntimeOwned(.panic, in: bridgeMode) else { return true }
            PanicRuntimeReducer.setPanic(
                isActive,
                state: &state,
                effects: &effects,
                liveAudioFadeDuration: environment.liveAudioFadeDuration,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorToggledPPTMode(let source):
            guard LiveRuntimeReducer.isRuntimeOwned(.ppt, in: bridgeMode) else { return true }
            PPTRuntimeReducer.toggleMode(source: source, state: &state, effects: &effects)

        case .operatorSetPPTMode(let isEnabled, let source):
            guard LiveRuntimeReducer.isRuntimeOwned(.ppt, in: bridgeMode) else { return true }
            PPTRuntimeReducer.setMode(
                isEnabled,
                source: source,
                state: &state,
                effects: &effects
            )

        case .operatorToggledProjection:
            guard LiveRuntimeReducer.isRuntimeOwned(.projection, in: bridgeMode) else { return true }
            ProjectionRuntimeReducer.toggleProjection(
                state: &state,
                effects: &effects,
                canWriteSupport: LiveRuntimeReducer.canGenerateReducerSupport(in: bridgeMode),
                now: environment.now
            )

        case .panicBGMPauseDelayElapsed(let generation, let snapshot):
            guard LiveRuntimeReducer.isRuntimeOwned(.panic, in: bridgeMode) else { return true }
            PanicRuntimeReducer.bgmPauseDelayElapsed(
                generation: generation,
                snapshot: snapshot,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .projectionStartFailed(let reason):
            guard LiveRuntimeReducer.isRuntimeOwned(.projection, in: bridgeMode) else { return true }
            ProjectionRuntimeReducer.startFailed(reason: reason, state: &state)

        case .projectionExternalDisplayLost:
            guard LiveRuntimeReducer.isRuntimeOwned(.projection, in: bridgeMode) else { return true }
            ProjectionRuntimeReducer.externalDisplayLost(
                state: &state,
                effects: &effects,
                canWriteSupport: LiveRuntimeReducer.canGenerateReducerSupport(in: bridgeMode),
                now: environment.now
            )

        case .projectionExternalDisplayAvailable:
            guard LiveRuntimeReducer.isRuntimeOwned(.projection, in: bridgeMode) else { return true }
            ProjectionRuntimeReducer.externalDisplayAvailable(state: &state)

        case .projectionExternalDisplayUnavailable:
            guard LiveRuntimeReducer.isRuntimeOwned(.projection, in: bridgeMode) else { return true }
            ProjectionRuntimeReducer.externalDisplayUnavailable(
                state: &state,
                effects: &effects,
                now: environment.now
            )

        case .pptEventTapStarted:
            guard LiveRuntimeReducer.isRuntimeOwned(.ppt, in: bridgeMode) else { return true }
            PPTRuntimeReducer.eventTapStarted(state: &state)

        case .pptEventTapFailed(let reason):
            guard LiveRuntimeReducer.isRuntimeOwned(.ppt, in: bridgeMode) else { return true }
            PPTRuntimeReducer.eventTapFailed(reason: reason, state: &state)

        case .pptEventTapStopped(let reason):
            guard LiveRuntimeReducer.isRuntimeOwned(.ppt, in: bridgeMode) else { return true }
            PPTRuntimeReducer.eventTapStopped(reason: reason, state: &state)

        default:
            return false
        }

        return true
    }
}
