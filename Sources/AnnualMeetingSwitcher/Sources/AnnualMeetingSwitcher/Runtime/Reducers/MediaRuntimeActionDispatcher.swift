enum MediaRuntimeActionDispatcher {
    static func dispatch(
        action: LiveRuntimeAction,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        environment: LiveRuntimeEnvironment
    ) -> Bool {
        let bridgeMode = environment.bridgeMode

        switch action {
        case .operatorToggledMediaPlayback:
            guard LiveRuntimeReducer.isRuntimeOwned(.media, in: bridgeMode) else { return true }
            MediaRuntimeReducer.togglePlayback(
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorRestartedCurrentMedia:
            guard LiveRuntimeReducer.isRuntimeOwned(.media, in: bridgeMode) else { return true }
            MediaRuntimeReducer.restartCurrent(
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorReturnedCurrentMediaToStart:
            guard LiveRuntimeReducer.isRuntimeOwned(.media, in: bridgeMode) else { return true }
            MediaRuntimeReducer.returnCurrentToStart(
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorSeekedCurrentMediaToStart:
            guard LiveRuntimeReducer.isRuntimeOwned(.media, in: bridgeMode) else { return true }
            MediaRuntimeReducer.seekCurrentToStart(state: &state, effects: &effects)

        case .operatorSeekedCurrentMediaToEnd:
            guard LiveRuntimeReducer.isRuntimeOwned(.media, in: bridgeMode) else { return true }
            MediaRuntimeReducer.seekCurrentToEnd(state: &state, effects: &effects)

        case .operatorSeekedCurrentMediaToProgress(let progress):
            guard LiveRuntimeReducer.isRuntimeOwned(.media, in: bridgeMode) else { return true }
            MediaRuntimeReducer.seekCurrent(toProgress: progress, state: &state, effects: &effects)

        case .operatorStoppedCurrentMedia:
            guard LiveRuntimeReducer.isRuntimeOwned(.media, in: bridgeMode) else { return true }
            MediaRuntimeReducer.stopCurrent(
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorPausedMediaForPanic(let generation):
            guard LiveRuntimeReducer.isRuntimeOwned(.media, in: bridgeMode) else { return true }
            MediaRuntimeReducer.pauseForPanic(
                generation: generation,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorResumedMediaAfterPanic(let generation):
            guard LiveRuntimeReducer.isRuntimeOwned(.media, in: bridgeMode) else { return true }
            MediaRuntimeReducer.resumeAfterPanic(
                generation: generation,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .mediaLoaded(let url, let generation):
            guard LiveRuntimeReducer.isRuntimeOwned(.media, in: bridgeMode) else { return true }
            MediaRuntimeReducer.loaded(url: url, generation: generation, state: &state)

        case .mediaPlaybackChanged(let isPlaying, let generation):
            guard LiveRuntimeReducer.isRuntimeOwned(.media, in: bridgeMode) else { return true }
            MediaRuntimeReducer.playbackChanged(
                isPlaying: isPlaying,
                generation: generation,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .mediaReachedEnd(let generation):
            guard LiveRuntimeReducer.isRuntimeOwned(.media, in: bridgeMode) else { return true }
            MediaRuntimeReducer.reachedEnd(
                generation: generation,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .mediaSeekCompleted(let time, let generation):
            guard LiveRuntimeReducer.isRuntimeOwned(.media, in: bridgeMode) else { return true }
            MediaRuntimeReducer.seekCompleted(time: time, generation: generation, state: &state)

        default:
            return false
        }

        return true
    }
}
