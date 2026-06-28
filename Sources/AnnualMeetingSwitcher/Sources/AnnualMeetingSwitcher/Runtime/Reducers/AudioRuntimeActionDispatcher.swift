enum AudioRuntimeActionDispatcher {
    static func dispatch(
        action: LiveRuntimeAction,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        environment: LiveRuntimeEnvironment
    ) -> Bool {
        let bridgeMode = environment.bridgeMode

        switch action {
        case .operatorSelectedAudioStrategy(let strategy):
            guard LiveRuntimeReducer.isRuntimeOwned(.audio, in: bridgeMode) else { return true }
            AudioRuntimeReducer.selectStrategy(
                strategy,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorChangedMasterVolume(let volume):
            guard LiveRuntimeReducer.isRuntimeOwned(.audio, in: bridgeMode) else { return true }
            AudioRuntimeReducer.changeMasterVolume(
                volume,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorChangedMediaVolume(let volume):
            guard LiveRuntimeReducer.isRuntimeOwned(.audio, in: bridgeMode) else { return true }
            AudioRuntimeReducer.changeMediaVolume(
                volume,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorChangedBGMVolume(let volume):
            guard LiveRuntimeReducer.isRuntimeOwned(.audio, in: bridgeMode) else { return true }
            AudioRuntimeReducer.changeBGMVolume(
                volume,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorChangedMasterMute(let isMuted):
            guard LiveRuntimeReducer.isRuntimeOwned(.audio, in: bridgeMode) else { return true }
            AudioRuntimeReducer.changeMasterMute(
                isMuted,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorChangedMediaMute(let isMuted):
            guard LiveRuntimeReducer.isRuntimeOwned(.audio, in: bridgeMode) else { return true }
            AudioRuntimeReducer.changeMediaMute(
                isMuted,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorChangedBGMMute(let isMuted):
            guard LiveRuntimeReducer.isRuntimeOwned(.audio, in: bridgeMode) else { return true }
            AudioRuntimeReducer.changeBGMMute(
                isMuted,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorChangedBGMTakeover(let isActive):
            guard LiveRuntimeReducer.isRuntimeOwned(.audio, in: bridgeMode) else { return true }
            AudioRuntimeReducer.changeBGMTakeover(
                isActive,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorToggledSpeakerMode:
            guard LiveRuntimeReducer.isRuntimeOwned(.audio, in: bridgeMode) else { return true }
            AudioRuntimeReducer.toggleSpeakerMode(
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorSetSpeakerMode(let isEnabled):
            guard LiveRuntimeReducer.isRuntimeOwned(.audio, in: bridgeMode) else { return true }
            AudioRuntimeReducer.setSpeakerMode(
                isEnabled,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .facadeAudioInputsChanged(let snapshot):
            guard LiveRuntimeReducer.isRuntimeOwned(.audio, in: bridgeMode) else { return true }
            AudioRuntimeReducer.applyFacadeSnapshot(
                snapshot,
                to: &state,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        default:
            return false
        }

        return true
    }
}
