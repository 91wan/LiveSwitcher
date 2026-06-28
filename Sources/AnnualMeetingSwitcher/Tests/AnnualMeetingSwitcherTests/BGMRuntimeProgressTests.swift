import XCTest
@testable import LiveSwitcher

final class BGMRuntimeReducerProgressTests: XCTestCase {
    func testSeekBGMToBeginningResetsProgressAndTime() {
        let item = bgmRuntimeReducerTestItem(title: "Seek Start")
        var state = bgmRuntimeReducerTestPlayingState(item: item, generation: 4)
        state.bgm.progress = 0.6
        state.bgm.currentTime = 60
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.seekToBeginning(state: &state, effects: &effects)

        XCTAssertEqual(state.bgm.progress, 0)
        XCTAssertEqual(state.bgm.currentTime, 0)
        XCTAssertTrue(effects.contains(.seekBGMToBeginning(generation: 4)))
    }

    func testSeekBGMToProgressClampsLowValue() {
        let item = bgmRuntimeReducerTestItem(title: "Low")
        var state = bgmRuntimeReducerTestPlayingState(item: item, generation: 4)
        state.bgm.duration = 100
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.seekToProgress(-0.2, state: &state, effects: &effects)

        XCTAssertEqual(state.bgm.progress, 0)
        XCTAssertEqual(state.bgm.currentTime, 0)
        XCTAssertTrue(effects.contains(.seekBGMToProgress(0, generation: 4)))
    }

    func testSeekBGMToProgressClampsHighValue() {
        let item = bgmRuntimeReducerTestItem(title: "High")
        var state = bgmRuntimeReducerTestPlayingState(item: item, generation: 4)
        state.bgm.duration = 100
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.seekToProgress(1.2, state: &state, effects: &effects)

        XCTAssertEqual(state.bgm.progress, 1)
        XCTAssertEqual(state.bgm.currentTime, 100)
        XCTAssertTrue(effects.contains(.seekBGMToProgress(1, generation: 4)))
    }

    func testSeekBGMToProgressUpdatesCurrentTimeWhenDurationIsKnown() {
        let item = bgmRuntimeReducerTestItem(title: "Known Duration")
        var state = bgmRuntimeReducerTestPlayingState(item: item, generation: 4)
        state.bgm.duration = 120
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.seekToProgress(0.25, state: &state, effects: &effects)

        XCTAssertEqual(state.bgm.currentTime, 30)
    }

    func testReachedEndLoopOneRestartsSameBGM() {
        let item = bgmRuntimeReducerTestItem(title: "Loop One")
        var state = bgmRuntimeReducerTestPlayingState(item: item, generation: 4)
        state.bgm.playMode = .loopOne
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.reachedEnd(
            generation: 4,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertEqual(state.bgm.currentID, item.id)
        XCTAssertTrue(state.bgm.isPlaying)
        XCTAssertTrue(effects.contains(.prepareBGM(item, generation: 5)))
    }

    func testReachedEndLoopAllAdvancesToNextBGM() {
        let first = bgmRuntimeReducerTestItem(title: "First")
        let second = bgmRuntimeReducerTestItem(title: "Second")
        var state = bgmRuntimeReducerTestPlayingState(item: first, generation: 4)
        state.bgm.items = [first, second]
        state.bgm.playMode = .loopAll
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.reachedEnd(
            generation: 4,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertEqual(state.bgm.currentID, second.id)
        XCTAssertTrue(effects.contains(.prepareBGM(second, generation: 5)))
    }

    func testReachedEndLoopAllWrapsToFirstBGM() {
        let first = bgmRuntimeReducerTestItem(title: "First")
        let second = bgmRuntimeReducerTestItem(title: "Second")
        var state = bgmRuntimeReducerTestPlayingState(item: second, generation: 4)
        state.bgm.items = [first, second]
        state.bgm.playMode = .loopAll
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.reachedEnd(
            generation: 4,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertEqual(state.bgm.currentID, first.id)
        XCTAssertTrue(effects.contains(.prepareBGM(first, generation: 5)))
    }

    func testReachedEndSequentialAdvancesWhenNextExists() {
        let first = bgmRuntimeReducerTestItem(title: "First")
        let second = bgmRuntimeReducerTestItem(title: "Second")
        var state = bgmRuntimeReducerTestPlayingState(item: first, generation: 4)
        state.bgm.items = [first, second]
        state.bgm.playMode = .sequential
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.reachedEnd(
            generation: 4,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertEqual(state.bgm.currentID, second.id)
        XCTAssertTrue(state.bgm.isPlaying)
    }

    func testReachedEndSequentialStopsAtEnd() {
        let first = bgmRuntimeReducerTestItem(title: "First")
        let second = bgmRuntimeReducerTestItem(title: "Second")
        var state = bgmRuntimeReducerTestPlayingState(item: second, generation: 4)
        state.bgm.items = [first, second]
        state.bgm.playMode = .sequential
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.reachedEnd(
            generation: 4,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertFalse(state.bgm.isPlaying)
        XCTAssertTrue(effects.contains(.stopBGM(fade: 0, generation: 5)))
    }

    func testReachedEndStopsWhenCurrentBGMIsMissing() {
        let item = bgmRuntimeReducerTestItem(title: "Missing")
        var state = bgmRuntimeReducerTestPlayingState(item: item, generation: 4)
        state.bgm.currentID = UUID()
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.reachedEnd(
            generation: 4,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertFalse(state.bgm.isPlaying)
        XCTAssertTrue(effects.contains(.stopBGMTimer(generation: 5)))
    }

    func testReachedEndStopsWhenCategoryItemsAreMissing() {
        let warmUp = bgmRuntimeReducerTestItem(title: "Warm", category: .warmUp)
        let entrance = bgmRuntimeReducerTestItem(title: "Entrance", category: .entrance)
        var state = bgmRuntimeReducerTestPlayingState(item: warmUp, generation: 4)
        state.bgm.items = [entrance]
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.reachedEnd(
            generation: 4,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertFalse(state.bgm.isPlaying)
        XCTAssertTrue(effects.contains(.stopBGM(fade: 0, generation: 5)))
    }
}
