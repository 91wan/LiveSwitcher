import Foundation

enum PanicRuntimeReducer {
    static func setPanic(
        _ isActive: Bool,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        liveAudioFadeDuration: TimeInterval,
        speakerModeDuckedRatio: Float
    ) {
        guard state.panic.isActive != isActive else { return }
        if isActive {
            activate(
                state: &state,
                effects: &effects,
                liveAudioFadeDuration: liveAudioFadeDuration
            )
        } else {
            deactivate(state: &state, effects: &effects)
        }
        syncAudio(state: &state, effects: &effects, speakerModeDuckedRatio: speakerModeDuckedRatio)
    }

    static func bgmPauseDelayElapsed(
        generation: Int,
        snapshot: PanicPlaybackSnapshot,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        guard state.panic.isActive else { return }
        guard state.panic.generation == generation else { return }
        guard PanicTransitionPolicy.shouldPauseBGMAfterFadeForActivation(
            snapshot: snapshot,
            currentBGM: state.bgm.currentItem
        ) else { return }

        state.bgm.isPlaying = false
        effects.append(.pauseBGM(generation: state.bgm.generation))
        syncAudio(state: &state, effects: &effects, speakerModeDuckedRatio: speakerModeDuckedRatio)
    }

    private static func activate(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        liveAudioFadeDuration: TimeInterval
    ) {
        state.panic.generation += 1
        let snapshot = PanicTransitionPolicy.snapshot(
            currentProgram: state.program.effectiveCurrentItem,
            isMediaPlaying: state.media.isPlaying,
            currentBGM: state.bgm.currentItem,
            isBGMPlaying: state.bgm.isPlaying
        )
        state.panic.snapshot = snapshot
        state.panic.isActive = true

        if PanicTransitionPolicy.shouldPauseMediaForActivation(
            snapshot: snapshot,
            currentProgram: state.program.effectiveCurrentItem
        ) {
            state.media.isPlaying = false
            effects.append(.pauseMedia(generation: state.media.generation))
        }

        guard PanicTransitionPolicy.shouldPauseBGMAfterFadeForActivation(
            snapshot: snapshot,
            currentBGM: state.bgm.currentItem
        ) else { return }

        if liveAudioFadeDuration > 0 {
            effects.append(.schedulePanicBGMPause(
                generation: state.panic.generation,
                snapshot: snapshot,
                delay: liveAudioFadeDuration
            ))
        } else {
            state.bgm.isPlaying = false
            effects.append(.pauseBGM(generation: state.bgm.generation))
        }
    }

    private static func deactivate(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        let snapshot = state.panic.snapshot
        let generation = state.panic.generation
        state.panic.generation += 1
        state.panic.isActive = false
        state.panic.snapshot = nil
        effects.append(.cancelPanicBGMPause(generation: generation))

        if PanicTransitionPolicy.shouldResumeMediaAfterDeactivation(
            snapshot: snapshot,
            currentProgram: state.program.effectiveCurrentItem
        ) {
            state.media.isPlaying = true
            state.media.didPlayToEnd = false
            effects.append(.playMedia(generation: state.media.generation))
        }

        if PanicTransitionPolicy.shouldResumeBGMAfterDeactivation(
            snapshot: snapshot,
            currentBGM: state.bgm.currentItem
        ) {
            state.bgm.isPlaying = true
            effects.append(.playBGM(generation: state.bgm.generation))
        }
    }

    private static func syncAudio(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        LiveRuntimeReducer.syncAudioRoutingContextFromMirrorState(&state)
        LiveRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .panicChanged))
    }
}
