import Foundation

enum ProgramSelectionRuntimeReducer {
    static func selectProgram(
        _ item: ProgramItem,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        now: Date,
        speakerModeDuckedRatio: Float
    ) {
        state.program.currentID = item.id
        state.program.currentDetachedItem = state.program.items.contains { $0.id == item.id } ? nil : item
        state.program.currentSwitchedAt = now

        if item.sourceKind == .media, let url = item.sourceURL {
            state.media.generation += 1
            state.media.loadedURL = url
            state.media.isPlaying = !state.panic.isActive
            state.media.didPlayToEnd = false
            state.media.currentTime = 0
            effects.append(.setMediaVolume(0, fade: 0, generation: state.media.generation))
            effects.append(.loadMedia(url, generation: state.media.generation))
            if !state.panic.isActive {
                effects.append(.playMedia(generation: state.media.generation))
            }
        } else {
            if state.media.loadedURL != nil || state.media.isPlaying {
                state.media.generation += 1
                state.media.isPlaying = false
                state.media.didPlayToEnd = false
                effects.append(.stopMedia(generation: state.media.generation))
            }
            state.media.loadedURL = nil
        }

        LiveRuntimeReducer.syncAudioRoutingContextFromMirrorState(&state)
        LiveRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .programChanged))
    }

    static func clearCurrentProgram(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        state.program.currentID = nil
        state.program.currentDetachedItem = nil
        state.program.currentSwitchedAt = nil
        state.audio.routingContext.isCurrentProgramMediaSource = false
        LiveRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .programChanged))
    }

    static func selectedProgramItem(_ id: UUID, in state: LiveRuntimeState) -> ProgramItem? {
        if let item = state.program.items.first(where: { $0.id == id }) {
            return item
        }
        if state.program.currentDetachedItem?.id == id {
            return state.program.currentDetachedItem
        }
        return nil
    }
}
