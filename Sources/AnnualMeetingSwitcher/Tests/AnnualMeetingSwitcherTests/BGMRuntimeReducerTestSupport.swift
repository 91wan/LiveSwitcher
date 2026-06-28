import Foundation
@testable import LiveSwitcher

func bgmRuntimeReducerTestPlayingState(item: BGMItem, generation: Int) -> LiveRuntimeState {
    var state = LiveRuntimeState()
    state.bgm.items = [item]
    state.bgm.currentID = item.id
    state.bgm.phase = .playing
    state.bgm.generation = generation
    return state
}

func bgmRuntimeReducerTestStoppedState(item: BGMItem, generation: Int) -> LiveRuntimeState {
    var state = bgmRuntimeReducerTestPlayingState(item: item, generation: generation)
    state.bgm.phase = .selected
    return state
}

func bgmRuntimeReducerTestPausedState(item: BGMItem, generation: Int) -> LiveRuntimeState {
    var state = bgmRuntimeReducerTestPlayingState(item: item, generation: generation)
    state.bgm.phase = .paused
    return state
}

func bgmRuntimeReducerTestPanicPausedState(item: BGMItem, generation: Int) -> LiveRuntimeState {
    var state = bgmRuntimeReducerTestPausedState(item: item, generation: generation)
    state.panic.isActive = true
    state.panic.snapshot = PanicPlaybackSnapshot(
        currentProgramID: nil,
        wasMediaPlaying: false,
        currentBGMID: item.id,
        wasBGMPlaying: true
    )
    return state
}

func bgmRuntimeReducerTestSelectedState(item: BGMItem, generation: Int) -> LiveRuntimeState {
    var state = bgmRuntimeReducerTestPlayingState(item: item, generation: generation)
    state.bgm.phase = .selected
    return state
}

func bgmRuntimeReducerTestItem(title: String, category: BGMCategory = .warmUp) -> BGMItem {
    BGMItem(
        id: UUID(),
        title: title,
        url: URL(fileURLWithPath: "/tmp/\(title).mp3"),
        category: category
    )
}
