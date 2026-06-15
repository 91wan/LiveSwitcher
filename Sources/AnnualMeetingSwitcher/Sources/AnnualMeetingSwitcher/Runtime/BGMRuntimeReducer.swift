import Foundation

enum BGMRuntimeReducer {
    static func selectBGM(
        id: UUID,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio
    ) {
        guard let item = state.bgm.items.first(where: { $0.id == id }) else { return }
        PanicRuntimeReducer.markBGMStoppedIfCurrentBGMMatchesSnapshot(state: &state)
        state.bgm.generation += 1
        state.bgm.currentID = id
        state.bgm.progress = 0
        state.bgm.currentTime = 0
        state.bgm.duration = nil
        if state.panic.isActive {
            state.bgm.isPlaying = false
            effects += [
                .stopBGM(fade: 0, generation: state.bgm.generation),
                .stopBGMTimer(generation: state.bgm.generation),
                .applyAudioRouting(reason: .bgmPlaybackChanged)
            ]
        } else {
            state.bgm.isPlaying = true
            effects += [
                .prepareBGM(item, generation: state.bgm.generation),
                .playBGM(generation: state.bgm.generation),
                .startBGMTimer(generation: state.bgm.generation),
                .applyAudioRouting(reason: .bgmPlaybackChanged)
            ]
        }
        LiveRuntimeReducer.syncAudioRoutingContextFromMirrorState(&state)
        LiveRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
    }

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

    static func stop(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        liveAudioFadeDuration: TimeInterval,
        speakerModeDuckedRatio: Float
    ) {
        PanicRuntimeReducer.markBGMStoppedIfCurrentBGMMatchesSnapshot(state: &state)
        state.bgm.generation += 1
        state.bgm.isPlaying = false
        effects += [
            .stopBGM(fade: liveAudioFadeDuration, generation: state.bgm.generation),
            .stopBGMTimer(generation: state.bgm.generation),
            .applyAudioRouting(reason: .bgmPlaybackChanged)
        ]
        LiveRuntimeReducer.syncAudioRoutingContextFromMirrorState(&state)
        LiveRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
    }

    static func selectAdjacent(
        offset: Int,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        guard let categoryItems = currentCategoryBGMItems(in: state),
              let currentID = state.bgm.currentID,
              let index = categoryItems.firstIndex(where: { $0.id == currentID }),
              !categoryItems.isEmpty
        else { return }
        let nextIndex = (index + offset + categoryItems.count) % categoryItems.count
        let nextItem = categoryItems[nextIndex]
        PanicRuntimeReducer.markBGMStoppedIfCurrentBGMMatchesSnapshot(state: &state)
        state.bgm.generation += 1
        state.bgm.currentID = nextItem.id
        state.bgm.progress = 0
        state.bgm.currentTime = 0
        state.bgm.duration = nil
        if state.panic.isActive {
            state.bgm.isPlaying = false
            effects += [
                .stopBGM(fade: 0, generation: state.bgm.generation),
                .stopBGMTimer(generation: state.bgm.generation),
                .applyAudioRouting(reason: .bgmPlaybackChanged)
            ]
        } else {
            state.bgm.isPlaying = true
            effects += [
                .prepareBGM(nextItem, generation: state.bgm.generation),
                .playBGM(generation: state.bgm.generation),
                .startBGMTimer(generation: state.bgm.generation),
                .applyAudioRouting(reason: .bgmPlaybackChanged)
            ]
        }
        LiveRuntimeReducer.syncAudioRoutingContextFromMirrorState(&state)
        LiveRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
    }

    static func pauseForPanic(
        generation: Int?,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        let targetGeneration = generation ?? state.bgm.generation
        guard targetGeneration == state.bgm.generation else { return }
        guard state.bgm.isPlaying else { return }
        state.bgm.isPlaying = false
        LiveRuntimeReducer.syncAudioRoutingContextFromMirrorState(&state)
        effects.append(.pauseBGM(generation: targetGeneration))
        LiveRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
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
        state.bgm.isPlaying = true
        LiveRuntimeReducer.syncAudioRoutingContextFromMirrorState(&state)
        effects += [
            .setBGMVolume(0, fade: 0, generation: targetGeneration),
            .playBGM(generation: targetGeneration)
        ]
        LiveRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .panicChanged))
    }

    static func playbackChanged(
        isPlaying: Bool,
        generation: Int,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        guard generation == state.bgm.generation else { return }
        state.bgm.isPlaying = isPlaying
        state.audio.routingContext.isBGMPlaying = isPlaying
        LiveRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
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
        state.bgm.isPlaying = false
        state.audio.routingContext.isBGMPlaying = false
        if canWriteSupport {
            state.support.record(kind: .bgmPlaybackFailed, detail: "reason=\(reason)", at: now)
        }
        effects += [
            .stopBGM(fade: 0, generation: state.bgm.generation),
            .stopBGMTimer(generation: state.bgm.generation)
        ]
        LiveRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .bgmPlaybackChanged))
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

    private static func reduceReachedEnd(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        guard !state.panic.isActive else {
            stopFinished(
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: speakerModeDuckedRatio
            )
            return
        }

        guard let categoryItems = currentCategoryBGMItems(in: state),
              let currentID = state.bgm.currentID,
              let index = categoryItems.firstIndex(where: { $0.id == currentID })
        else {
            stopFinished(
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: speakerModeDuckedRatio
            )
            return
        }

        switch state.bgm.playMode {
        case .loopOne:
            restart(
                categoryItems[index],
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: speakerModeDuckedRatio
            )
        case .loopAll:
            let nextIndex = (index + 1) % categoryItems.count
            restart(
                categoryItems[nextIndex],
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: speakerModeDuckedRatio
            )
        case .sequential:
            if index < categoryItems.count - 1 {
                restart(
                    categoryItems[index + 1],
                    state: &state,
                    effects: &effects,
                    speakerModeDuckedRatio: speakerModeDuckedRatio
                )
            } else {
                stopFinished(
                    state: &state,
                    effects: &effects,
                    speakerModeDuckedRatio: speakerModeDuckedRatio
                )
            }
        }
    }

    private static func currentCategoryBGMItems(in state: LiveRuntimeState) -> [BGMItem]? {
        guard let currentID = state.bgm.currentID,
              let currentItem = state.bgm.items.first(where: { $0.id == currentID })
        else { return nil }
        return state.bgm.items.filter { $0.category == currentItem.category }
    }

    private static func restart(
        _ item: BGMItem,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        state.bgm.generation += 1
        state.bgm.currentID = item.id
        state.bgm.isPlaying = true
        state.bgm.progress = 0
        state.bgm.currentTime = 0
        state.bgm.duration = nil
        effects += [
            .prepareBGM(item, generation: state.bgm.generation),
            .playBGM(generation: state.bgm.generation),
            .startBGMTimer(generation: state.bgm.generation),
            .applyAudioRouting(reason: .bgmPlaybackChanged)
        ]
        LiveRuntimeReducer.syncAudioRoutingContextFromMirrorState(&state)
        LiveRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
    }

    private static func stopFinished(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        state.bgm.generation += 1
        state.bgm.isPlaying = false
        state.bgm.progress = 0
        state.bgm.currentTime = 0
        state.bgm.duration = nil
        effects += [
            .stopBGM(fade: 0, generation: state.bgm.generation),
            .stopBGMTimer(generation: state.bgm.generation)
        ]
        LiveRuntimeReducer.syncAudioRoutingContextFromMirrorState(&state)
        LiveRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .bgmPlaybackChanged))
    }
}
