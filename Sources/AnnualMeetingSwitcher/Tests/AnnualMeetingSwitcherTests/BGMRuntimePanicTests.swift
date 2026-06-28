import XCTest
@testable import LiveSwitcher

final class BGMRuntimeReducerPanicTests: XCTestCase {
    func testPauseBGMForPanicUsesCurrentGenerationWhenNil() {
        let item = bgmRuntimeReducerTestItem(title: "Pause")
        var state = bgmRuntimeReducerTestPlayingState(item: item, generation: 6)
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.pauseForPanic(
            generation: nil,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertFalse(state.bgm.isPlaying)
        XCTAssertTrue(effects.contains(.pauseBGM(generation: 6)))
    }

    func testPauseBGMForPanicIgnoresStaleGeneration() {
        let item = bgmRuntimeReducerTestItem(title: "Stale Pause")
        var state = bgmRuntimeReducerTestPlayingState(item: item, generation: 6)
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.pauseForPanic(
            generation: 5,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertTrue(state.bgm.isPlaying)
        XCTAssertTrue(effects.isEmpty)
    }

    func testResumeBGMAfterPanicUsesCurrentGenerationWhenNil() {
        let item = bgmRuntimeReducerTestItem(title: "Resume")
        var state = bgmRuntimeReducerTestPanicPausedState(item: item, generation: 9)
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.resumeAfterPanic(
            generation: nil,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertTrue(state.bgm.isPlaying)
        XCTAssertTrue(effects.contains(.playBGM(generation: 9)))
    }

    func testResumeBGMAfterPanicSetsVolumeZeroBeforePlay() {
        let item = bgmRuntimeReducerTestItem(title: "Fade Resume")
        var state = bgmRuntimeReducerTestPanicPausedState(item: item, generation: 9)
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.resumeAfterPanic(
            generation: nil,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertEqual(effects.first, .setBGMVolume(0, fade: 0, generation: 9))
        XCTAssertEqual(effects.dropFirst().first, .playBGM(generation: 9))
    }

    func testResumeBGMAfterPanicIgnoresStaleGeneration() {
        let item = bgmRuntimeReducerTestItem(title: "Stale Resume")
        var state = bgmRuntimeReducerTestStoppedState(item: item, generation: 9)
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.resumeAfterPanic(
            generation: 8,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertFalse(state.bgm.isPlaying)
        XCTAssertTrue(effects.isEmpty)
    }

    func testReachedEndStopsWhenPanicActive() {
        let item = bgmRuntimeReducerTestItem(title: "Panic Stop")
        var state = bgmRuntimeReducerTestPlayingState(item: item, generation: 4)
        state.panic.isActive = true
        state.bgm.playMode = .loopOne
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
