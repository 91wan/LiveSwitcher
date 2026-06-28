import Foundation

enum BGMRuntimeProgressReducer {
    static func setPlayMode(
        _ playMode: BGMPlayMode,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        state.bgm.playMode = playMode
        effects += [
            .setBGMPlayMode(playMode, generation: state.bgm.currentID == nil ? nil : state.bgm.generation),
            .saveBGMPlayMode(playMode)
        ]
    }

    static func seekToBeginning(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        guard state.bgm.currentID != nil else { return }
        state.bgm.progress = 0
        state.bgm.currentTime = 0
        effects.append(.seekBGMToBeginning(generation: state.bgm.generation))
    }

    static func seekToProgress(
        _ progress: Double,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        guard state.bgm.currentID != nil else { return }
        let clampedProgress = min(max(progress, 0), 1)
        state.bgm.progress = clampedProgress
        if let duration = state.bgm.duration, duration.isFinite, duration > 0 {
            state.bgm.currentTime = duration * clampedProgress
        }
        effects.append(.seekBGMToProgress(clampedProgress, generation: state.bgm.generation))
    }

    static func progressUpdated(
        time: Double,
        duration: Double?,
        generation: Int,
        state: inout LiveRuntimeState
    ) {
        guard generation == state.bgm.generation else { return }
        state.bgm.currentTime = max(0, time)
        state.bgm.duration = duration
        if let duration, duration > 0 {
            state.bgm.progress = min(max(time / duration, 0), 1)
        }
    }
}
