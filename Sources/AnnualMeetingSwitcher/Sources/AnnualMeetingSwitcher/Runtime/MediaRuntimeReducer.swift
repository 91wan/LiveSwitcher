import Foundation

enum MediaRuntimeReducer {
    static func togglePlayback(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        guard hasMediaPlaybackContext(state) else { return }
        guard !state.media.didPlayToEnd else { return }
        if state.panic.isActive {
            guard state.media.isPlaying else { return }
            state.media.isPlaying = false
            AudioRuntimeReducer.syncRoutingContextFromMirrorState(&state)
            effects.append(.pauseMedia(generation: state.media.generation))
            AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
            effects.append(.applyAudioRouting(reason: .panicChanged))
            return
        }
        state.media.isPlaying.toggle()
        AudioRuntimeReducer.syncRoutingContextFromMirrorState(&state)
        effects.append(state.media.isPlaying ? .playMedia(generation: state.media.generation) : .pauseMedia(generation: state.media.generation))
        AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .mediaPlaybackChanged))
    }

    private static func hasMediaPlaybackContext(_ state: LiveRuntimeState) -> Bool {
        state.media.loadedURL != nil
            || state.program.effectiveCurrentItem?.sourceKind == .media
    }

    static func restartCurrent(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        guard state.program.effectiveCurrentItem?.supportsSeeking == true else { return }
        state.media.didPlayToEnd = false
        state.media.currentTime = 0
        if state.panic.isActive {
            state.media.isPlaying = false
            AudioRuntimeReducer.syncRoutingContextFromMirrorState(&state)
            effects.append(.seekMediaToStart(generation: state.media.generation))
            AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
            effects.append(.applyAudioRouting(reason: .mediaPlaybackChanged))
            return
        }
        state.media.isPlaying = true
        AudioRuntimeReducer.syncRoutingContextFromMirrorState(&state)
        effects.append(.restartMedia(generation: state.media.generation))
        AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .mediaPlaybackChanged))
    }

    static func returnCurrentToStart(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        guard state.program.effectiveCurrentItem?.supportsSeeking == true else { return }
        let wasPlaying = state.media.isPlaying
        PanicRuntimeReducer.markMediaStoppedIfCurrentProgramMatchesSnapshot(state: &state)
        state.media.didPlayToEnd = false
        state.media.currentTime = 0
        state.media.isPlaying = false
        AudioRuntimeReducer.syncRoutingContextFromMirrorState(&state)
        effects.append(.pauseMedia(generation: state.media.generation))
        effects.append(.seekMediaToStart(generation: state.media.generation))
        guard wasPlaying else { return }
        AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .mediaPlaybackChanged))
    }

    static func seekCurrentToStart(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        guard state.program.effectiveCurrentItem?.supportsSeeking == true else { return }
        state.media.didPlayToEnd = false
        state.media.currentTime = 0
        effects.append(.seekMediaToStart(generation: state.media.generation))
    }

    static func seekCurrentToEnd(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        guard state.program.effectiveCurrentItem?.supportsSeeking == true else { return }
        state.media.didPlayToEnd = false
        if let duration = state.media.duration, duration.isFinite, duration > 0 {
            state.media.currentTime = duration
        }
        effects.append(.seekMediaToEnd(generation: state.media.generation))
    }

    static func stopCurrent(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        guard state.media.loadedURL != nil
                || state.media.isPlaying
                || state.program.effectiveCurrentItem?.sourceKind == .media
        else { return }
        PanicRuntimeReducer.markMediaStoppedIfCurrentProgramMatchesSnapshot(state: &state)
        state.media.generation += 1
        state.media.loadedURL = nil
        state.media.isPlaying = false
        state.media.didPlayToEnd = false
        state.media.currentTime = 0
        state.media.duration = nil
        AudioRuntimeReducer.syncRoutingContextFromMirrorState(&state)
        effects.append(.stopMedia(generation: state.media.generation))
        AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .mediaPlaybackChanged))
    }

    static func pauseForPanic(
        generation: Int?,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        let targetGeneration = generation ?? state.media.generation
        guard targetGeneration == state.media.generation else { return }
        guard state.media.isPlaying else { return }
        state.media.isPlaying = false
        AudioRuntimeReducer.syncRoutingContextFromMirrorState(&state)
        effects.append(.pauseMedia(generation: targetGeneration))
        AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .panicChanged))
    }

    static func resumeAfterPanic(
        generation: Int?,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        guard !state.panic.isActive else { return }
        let targetGeneration = generation ?? state.media.generation
        guard targetGeneration == state.media.generation else { return }
        state.media.isPlaying = true
        state.media.didPlayToEnd = false
        AudioRuntimeReducer.syncRoutingContextFromMirrorState(&state)
        effects += [
            .setMediaVolume(0, fade: 0, generation: targetGeneration),
            .playMedia(generation: targetGeneration)
        ]
        AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .panicChanged))
    }

    static func loaded(
        url: URL,
        generation: Int,
        state: inout LiveRuntimeState
    ) {
        guard generation == state.media.generation else { return }
        state.media.loadedURL = url
        state.media.didPlayToEnd = false
    }

    static func playbackChanged(
        isPlaying: Bool,
        generation: Int,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        guard generation == state.media.generation else { return }
        if state.panic.isActive {
            guard isPlaying else {
                state.media.isPlaying = false
                state.audio.routingContext.isMediaPlaying = false
                AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
                effects.append(.applyAudioRouting(reason: .mediaPlaybackChanged))
                return
            }
            state.media.isPlaying = false
            AudioRuntimeReducer.syncRoutingContextFromMirrorState(&state)
            effects.append(.pauseMedia(generation: generation))
            AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
            effects.append(.applyAudioRouting(reason: .panicChanged))
            return
        }
        state.media.isPlaying = isPlaying
        state.audio.routingContext.isMediaPlaying = isPlaying
        AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .mediaPlaybackChanged))
    }

    static func reachedEnd(
        generation: Int,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        guard generation == state.media.generation else { return }
        PanicRuntimeReducer.markMediaStoppedIfCurrentProgramMatchesSnapshot(state: &state)
        state.media.isPlaying = false
        state.media.didPlayToEnd = true
        state.audio.routingContext.isMediaPlaying = false
        AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .mediaPlaybackChanged))
    }

    static func seekCompleted(
        time: Double,
        generation: Int,
        state: inout LiveRuntimeState
    ) {
        guard generation == state.media.generation else { return }
        state.media.currentTime = max(0, time)
    }
}
