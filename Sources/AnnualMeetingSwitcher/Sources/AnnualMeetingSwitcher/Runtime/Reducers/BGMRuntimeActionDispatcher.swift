enum BGMRuntimeActionDispatcher {
    static func dispatch(
        action: LiveRuntimeAction,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        environment: LiveRuntimeEnvironment
    ) -> Bool {
        let bridgeMode = environment.bridgeMode

        switch action {
        case .operatorSelectedBGM(let id):
            guard LiveRuntimeReducer.isRuntimeOwned(.bgm, in: bridgeMode) else { return true }
            BGMRuntimeReducer.selectBGM(
                id: id,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorSelectedBGMPlayMode(let playMode):
            guard LiveRuntimeReducer.isRuntimeOwned(.bgm, in: bridgeMode) else { return true }
            BGMRuntimeReducer.setPlayMode(playMode, state: &state, effects: &effects)

        case .operatorSeekedBGMToBeginning:
            guard LiveRuntimeReducer.isRuntimeOwned(.bgm, in: bridgeMode) else { return true }
            BGMRuntimeReducer.seekToBeginning(state: &state, effects: &effects)

        case .operatorSeekedBGMToProgress(let progress):
            guard LiveRuntimeReducer.isRuntimeOwned(.bgm, in: bridgeMode) else { return true }
            BGMRuntimeReducer.seekToProgress(progress, state: &state, effects: &effects)

        case .operatorToggledCurrentBGMPlayback:
            guard LiveRuntimeReducer.isRuntimeOwned(.bgm, in: bridgeMode) else { return true }
            BGMRuntimeReducer.toggleCurrentPlayback(
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorStoppedBGM:
            guard LiveRuntimeReducer.isRuntimeOwned(.bgm, in: bridgeMode) else { return true }
            BGMRuntimeReducer.stop(
                state: &state,
                effects: &effects,
                liveAudioFadeDuration: environment.liveAudioFadeDuration,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorSelectedNextBGM:
            guard LiveRuntimeReducer.isRuntimeOwned(.bgm, in: bridgeMode) else { return true }
            BGMRuntimeReducer.selectAdjacent(
                offset: 1,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorSelectedPreviousBGM:
            guard LiveRuntimeReducer.isRuntimeOwned(.bgm, in: bridgeMode) else { return true }
            BGMRuntimeReducer.selectAdjacent(
                offset: -1,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorPausedBGMForPanic(let generation):
            guard LiveRuntimeReducer.isRuntimeOwned(.bgm, in: bridgeMode) else { return true }
            BGMRuntimeReducer.pauseForPanic(
                generation: generation,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorResumedBGMAfterPanic(let generation):
            guard LiveRuntimeReducer.isRuntimeOwned(.bgm, in: bridgeMode) else { return true }
            BGMRuntimeReducer.resumeAfterPanic(
                generation: generation,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .facadeBGMLibraryChanged(let items):
            guard LiveRuntimeReducer.isRuntimeOwned(.bgm, in: bridgeMode) else { return true }
            BGMRuntimeReducer.replaceLibrary(
                items,
                state: &state,
                effects: &effects,
                liveAudioFadeDuration: environment.liveAudioFadeDuration,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .bgmPlaybackChanged(let isPlaying, let generation):
            guard LiveRuntimeReducer.isRuntimeOwned(.bgm, in: bridgeMode) else { return true }
            BGMRuntimeReducer.playbackChanged(
                isPlaying: isPlaying,
                generation: generation,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .bgmReachedEnd(let generation):
            guard LiveRuntimeReducer.isRuntimeOwned(.bgm, in: bridgeMode) else { return true }
            BGMRuntimeReducer.reachedEnd(
                generation: generation,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .bgmFailed(let reason, let generation):
            guard LiveRuntimeReducer.isRuntimeOwned(.bgm, in: bridgeMode) else { return true }
            BGMRuntimeReducer.failed(
                reason: reason,
                generation: generation,
                state: &state,
                effects: &effects,
                canWriteSupport: LiveRuntimeReducer.canGenerateReducerSupport(in: bridgeMode),
                now: environment.now,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .bgmProgressUpdated(let time, let duration, let generation):
            guard LiveRuntimeReducer.isRuntimeOwned(.bgm, in: bridgeMode) else { return true }
            BGMRuntimeReducer.progressUpdated(
                time: time,
                duration: duration,
                generation: generation,
                state: &state
            )

        default:
            return false
        }

        return true
    }
}
