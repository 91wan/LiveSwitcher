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
            state.bgm.phase = .selected
            effects += [
                .stopBGM(fade: 0, generation: state.bgm.generation),
                .stopBGMTimer(generation: state.bgm.generation),
                .applyAudioRouting(reason: .bgmPlaybackChanged)
            ]
        } else {
            state.bgm.phase = .playing
            effects += [
                .prepareBGM(item, generation: state.bgm.generation),
                .playBGM(generation: state.bgm.generation),
                .startBGMTimer(generation: state.bgm.generation),
                .applyAudioRouting(reason: .bgmPlaybackChanged)
            ]
        }
        AudioRuntimeReducer.syncRoutingContextFromMirrorState(&state)
        AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
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

    static func replaceLibrary(
        _ items: [BGMItem],
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        liveAudioFadeDuration: TimeInterval,
        speakerModeDuckedRatio: Float
    ) {
        guard let currentID = state.bgm.currentID else {
            state.bgm.items = items
            return
        }
        guard !items.contains(where: { $0.id == currentID }) else {
            state.bgm.items = items
            return
        }

        PanicRuntimeReducer.markBGMStoppedIfCurrentBGMMatchesSnapshot(state: &state)
        state.bgm.items = items
        state.bgm.generation += 1
        state.bgm.currentID = nil
        state.bgm.phase = .idle
        state.bgm.progress = 0
        state.bgm.currentTime = 0
        state.bgm.duration = nil

        effects += [
            .stopBGM(fade: liveAudioFadeDuration, generation: state.bgm.generation),
            .stopBGMTimer(generation: state.bgm.generation)
        ]
        AudioRuntimeReducer.syncRoutingContextFromMirrorState(&state)
        AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .bgmPlaybackChanged))
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
            state.bgm.phase = .selected
            effects += [
                .stopBGM(fade: 0, generation: state.bgm.generation),
                .stopBGMTimer(generation: state.bgm.generation),
                .applyAudioRouting(reason: .bgmPlaybackChanged)
            ]
        } else {
            state.bgm.phase = .playing
            effects += [
                .prepareBGM(nextItem, generation: state.bgm.generation),
                .playBGM(generation: state.bgm.generation),
                .startBGMTimer(generation: state.bgm.generation),
                .applyAudioRouting(reason: .bgmPlaybackChanged)
            ]
        }
        AudioRuntimeReducer.syncRoutingContextFromMirrorState(&state)
        AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
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
