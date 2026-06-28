import Foundation

enum BGMRuntimeLibraryReducer {
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
}
