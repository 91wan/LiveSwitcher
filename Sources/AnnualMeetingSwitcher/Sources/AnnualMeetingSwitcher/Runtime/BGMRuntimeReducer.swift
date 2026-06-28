import Foundation

enum BGMRuntimeReducer {
    static func selectBGM(
        id: UUID,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio
    ) {
        BGMRuntimeSelectionReducer.selectBGM(
            id: id,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: speakerModeDuckedRatio
        )
    }

    static func setPlayMode(
        _ playMode: BGMPlayMode,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        BGMRuntimeProgressReducer.setPlayMode(playMode, state: &state, effects: &effects)
    }

    static func seekToBeginning(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        BGMRuntimeProgressReducer.seekToBeginning(state: &state, effects: &effects)
    }

    static func seekToProgress(
        _ progress: Double,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        BGMRuntimeProgressReducer.seekToProgress(progress, state: &state, effects: &effects)
    }

    static func toggleCurrentPlayback(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        BGMRuntimePlaybackReducer.toggleCurrentPlayback(
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: speakerModeDuckedRatio
        )
    }

    static func stop(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        liveAudioFadeDuration: TimeInterval,
        speakerModeDuckedRatio: Float
    ) {
        BGMRuntimePlaybackReducer.stop(
            state: &state,
            effects: &effects,
            liveAudioFadeDuration: liveAudioFadeDuration,
            speakerModeDuckedRatio: speakerModeDuckedRatio
        )
    }

    static func replaceLibrary(
        _ items: [BGMItem],
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        liveAudioFadeDuration: TimeInterval,
        speakerModeDuckedRatio: Float
    ) {
        BGMRuntimeLibraryReducer.replaceLibrary(
            items,
            state: &state,
            effects: &effects,
            liveAudioFadeDuration: liveAudioFadeDuration,
            speakerModeDuckedRatio: speakerModeDuckedRatio
        )
    }

    static func selectAdjacent(
        offset: Int,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        BGMRuntimeSelectionReducer.selectAdjacent(
            offset: offset,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: speakerModeDuckedRatio
        )
    }

    static func pauseForPanic(
        generation: Int?,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        BGMRuntimePanicReducer.pauseForPanic(
            generation: generation,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: speakerModeDuckedRatio
        )
    }

    static func resumeAfterPanic(
        generation: Int?,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        BGMRuntimePanicReducer.resumeAfterPanic(
            generation: generation,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: speakerModeDuckedRatio
        )
    }

    static func playbackChanged(
        isPlaying: Bool,
        generation: Int,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        BGMRuntimePlaybackReducer.playbackChanged(
            isPlaying: isPlaying,
            generation: generation,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: speakerModeDuckedRatio
        )
    }

    static func reachedEnd(
        generation: Int,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        BGMRuntimePlaybackReducer.reachedEnd(
            generation: generation,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: speakerModeDuckedRatio
        )
    }

    static func failed(
        reason: String,
        generation: Int,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        canWriteSupport: Bool,
        now: Date,
        speakerModeDuckedRatio: Float
    ) {
        BGMRuntimePlaybackReducer.failed(
            reason: reason,
            generation: generation,
            state: &state,
            effects: &effects,
            canWriteSupport: canWriteSupport,
            now: now,
            speakerModeDuckedRatio: speakerModeDuckedRatio
        )
    }

    static func progressUpdated(
        time: Double,
        duration: Double?,
        generation: Int,
        state: inout LiveRuntimeState
    ) {
        BGMRuntimeProgressReducer.progressUpdated(
            time: time,
            duration: duration,
            generation: generation,
            state: &state
        )
    }
}
