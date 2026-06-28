import Foundation

enum BGMRuntimePanicReducer {
    static func pauseForPanic(
        generation: Int?,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        let targetGeneration = generation ?? state.bgm.generation
        guard targetGeneration == state.bgm.generation else { return }
        guard state.bgm.isPlaying else { return }
        state.bgm.phase = .paused
        AudioRuntimeReducer.syncRoutingContextFromMirrorState(&state)
        effects += [
            .pauseBGM(generation: targetGeneration),
            .stopBGMTimer(generation: targetGeneration)
        ]
        AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .panicChanged))
    }

    static func resumeAfterPanic(
        generation: Int?,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        let targetGeneration = generation ?? state.bgm.generation
        guard targetGeneration == state.bgm.generation else { return }
        guard state.panic.snapshot?.wasBGMPlaying == true else { return }
        guard state.bgm.phase == .paused else { return }
        state.bgm.phase = .playing
        AudioRuntimeReducer.syncRoutingContextFromMirrorState(&state)
        effects += [
            .setBGMVolume(0, fade: 0, generation: targetGeneration),
            .playBGM(generation: targetGeneration),
            .startBGMTimer(generation: targetGeneration)
        ]
        AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .panicChanged))
    }
}
