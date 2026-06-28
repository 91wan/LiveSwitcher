import Foundation

enum BGMRuntimeSelectionReducer {
    static func selectBGM(
        id: UUID,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio
    ) {
        guard let item = state.bgm.items.first(where: { $0.id == id }) else { return }
        select(item, state: &state, effects: &effects, speakerModeDuckedRatio: speakerModeDuckedRatio)
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
        select(
            categoryItems[nextIndex],
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: speakerModeDuckedRatio
        )
    }

    static func currentCategoryBGMItems(in state: LiveRuntimeState) -> [BGMItem]? {
        guard let currentID = state.bgm.currentID,
              let currentItem = state.bgm.items.first(where: { $0.id == currentID })
        else { return nil }
        return state.bgm.items.filter { $0.category == currentItem.category }
    }

    private static func select(
        _ item: BGMItem,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        PanicRuntimeReducer.markBGMStoppedIfCurrentBGMMatchesSnapshot(state: &state)
        state.bgm.generation += 1
        state.bgm.currentID = item.id
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
}
