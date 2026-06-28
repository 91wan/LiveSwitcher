import Foundation

enum BGMRuntimePlaybackReducer {
    static func toggleCurrentPlayback(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        guard let currentItem = state.bgm.currentItem else { return }
        switch state.bgm.phase {
        case .playing:
            state.bgm.phase = .paused
            effects += [
                .pauseBGM(generation: state.bgm.generation),
                .stopBGMTimer(generation: state.bgm.generation),
                .applyAudioRouting(reason: .bgmPlaybackChanged)
            ]
        case .paused:
            guard !state.panic.isActive else { return }
            state.bgm.phase = .playing
            effects += [
                .playBGM(generation: state.bgm.generation),
                .startBGMTimer(generation: state.bgm.generation),
                .applyAudioRouting(reason: .bgmPlaybackChanged)
            ]
        case .selected:
            guard !state.panic.isActive else { return }
            state.bgm.generation += 1
            state.bgm.progress = 0
            state.bgm.currentTime = 0
            state.bgm.duration = nil
            state.bgm.phase = .playing
            effects += [
                .prepareBGM(currentItem, generation: state.bgm.generation),
                .playBGM(generation: state.bgm.generation),
                .startBGMTimer(generation: state.bgm.generation),
                .applyAudioRouting(reason: .bgmPlaybackChanged)
            ]
        case .idle:
            return
        }
        AudioRuntimeReducer.syncRoutingContextFromMirrorState(&state)
        AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
    }

    static func stop(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        liveAudioFadeDuration: TimeInterval,
        speakerModeDuckedRatio: Float
    ) {
        PanicRuntimeReducer.markBGMStoppedIfCurrentBGMMatchesSnapshot(state: &state)
        state.bgm.generation += 1
        state.bgm.phase = state.bgm.currentID == nil ? .idle : .selected
        state.bgm.progress = 0
        state.bgm.currentTime = 0
        state.bgm.duration = nil
        effects += [
            .stopBGM(fade: liveAudioFadeDuration, generation: state.bgm.generation),
            .stopBGMTimer(generation: state.bgm.generation),
            .applyAudioRouting(reason: .bgmPlaybackChanged)
        ]
        AudioRuntimeReducer.syncRoutingContextFromMirrorState(&state)
        AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
    }

    static func playbackChanged(
        isPlaying: Bool,
        generation: Int,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        guard generation == state.bgm.generation else { return }
        if isPlaying {
            state.bgm.phase = .playing
        } else if state.bgm.currentID == nil {
            state.bgm.phase = .idle
        } else {
            state.bgm.phase = .paused
        }
        state.audio.routingContext.isBGMPlaying = isPlaying
        AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .bgmPlaybackChanged))
    }

    static func reachedEnd(
        generation: Int,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        guard generation == state.bgm.generation else { return }
        PanicRuntimeReducer.markBGMStoppedIfCurrentBGMMatchesSnapshot(state: &state)
        reduceReachedEnd(
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
        guard generation == state.bgm.generation else { return }
        PanicRuntimeReducer.markBGMStoppedIfCurrentBGMMatchesSnapshot(state: &state)
        state.bgm.generation += 1
        state.bgm.phase = state.bgm.currentID == nil ? .idle : .selected
        state.audio.routingContext.isBGMPlaying = false
        if canWriteSupport {
            state.support.record(kind: .bgmPlaybackFailed, detail: "reason=\(reason)", at: now)
        }
        effects += [
            .stopBGM(fade: 0, generation: state.bgm.generation),
            .stopBGMTimer(generation: state.bgm.generation)
        ]
        AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .bgmPlaybackChanged))
    }

    private static func reduceReachedEnd(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        guard !state.panic.isActive else {
            stopFinished(state: &state, effects: &effects, speakerModeDuckedRatio: speakerModeDuckedRatio)
            return
        }

        guard let categoryItems = BGMRuntimeSelectionReducer.currentCategoryBGMItems(in: state),
              let currentID = state.bgm.currentID,
              let index = categoryItems.firstIndex(where: { $0.id == currentID })
        else {
            stopFinished(state: &state, effects: &effects, speakerModeDuckedRatio: speakerModeDuckedRatio)
            return
        }

        switch state.bgm.playMode {
        case .loopOne:
            restart(categoryItems[index], state: &state, effects: &effects, speakerModeDuckedRatio: speakerModeDuckedRatio)
        case .loopAll:
            let nextIndex = (index + 1) % categoryItems.count
            restart(categoryItems[nextIndex], state: &state, effects: &effects, speakerModeDuckedRatio: speakerModeDuckedRatio)
        case .sequential:
            if index < categoryItems.count - 1 {
                restart(categoryItems[index + 1], state: &state, effects: &effects, speakerModeDuckedRatio: speakerModeDuckedRatio)
            } else {
                stopFinished(state: &state, effects: &effects, speakerModeDuckedRatio: speakerModeDuckedRatio)
            }
        }
    }

    private static func restart(
        _ item: BGMItem,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        state.bgm.generation += 1
        state.bgm.currentID = item.id
        state.bgm.phase = .playing
        state.bgm.progress = 0
        state.bgm.currentTime = 0
        state.bgm.duration = nil
        effects += [
            .prepareBGM(item, generation: state.bgm.generation),
            .playBGM(generation: state.bgm.generation),
            .startBGMTimer(generation: state.bgm.generation),
            .applyAudioRouting(reason: .bgmPlaybackChanged)
        ]
        AudioRuntimeReducer.syncRoutingContextFromMirrorState(&state)
        AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
    }

    private static func stopFinished(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        state.bgm.generation += 1
        state.bgm.phase = state.bgm.currentID == nil ? .idle : .selected
        state.bgm.progress = 0
        state.bgm.currentTime = 0
        state.bgm.duration = nil
        effects += [
            .stopBGM(fade: 0, generation: state.bgm.generation),
            .stopBGMTimer(generation: state.bgm.generation)
        ]
        AudioRuntimeReducer.syncRoutingContextFromMirrorState(&state)
        AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .bgmPlaybackChanged))
    }
}
