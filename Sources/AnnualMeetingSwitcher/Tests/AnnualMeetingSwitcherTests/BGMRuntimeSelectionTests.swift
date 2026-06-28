import XCTest
@testable import LiveSwitcher

final class BGMRuntimeReducerSelectionTests: XCTestCase {
    func testSelectBGMPreparesPlaysAndStartsTimerWhenPanicInactive() {
        let item = bgmRuntimeReducerTestItem(title: "Walk In")
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.selectBGM(id: item.id, state: &state, effects: &effects)

        XCTAssertEqual(state.bgm.currentID, item.id)
        XCTAssertTrue(state.bgm.isPlaying)
        XCTAssertTrue(effects.contains(.prepareBGM(item, generation: 1)))
        XCTAssertTrue(effects.contains(.playBGM(generation: 1)))
        XCTAssertTrue(effects.contains(.startBGMTimer(generation: 1)))
    }

    func testSelectBGMStopsAndStopsTimerWhenPanicActive() {
        let item = bgmRuntimeReducerTestItem(title: "Panic Cue")
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        state.panic.isActive = true
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.selectBGM(id: item.id, state: &state, effects: &effects)

        XCTAssertEqual(state.bgm.currentID, item.id)
        XCTAssertFalse(state.bgm.isPlaying)
        XCTAssertTrue(effects.contains(.stopBGM(fade: 0, generation: 1)))
        XCTAssertTrue(effects.contains(.stopBGMTimer(generation: 1)))
    }

    func testSelectBGMResetsProgressTimeAndDuration() {
        let item = bgmRuntimeReducerTestItem(title: "Reset")
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        state.bgm.progress = 0.8
        state.bgm.currentTime = 80
        state.bgm.duration = 100
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.selectBGM(id: item.id, state: &state, effects: &effects)

        XCTAssertEqual(state.bgm.progress, 0)
        XCTAssertEqual(state.bgm.currentTime, 0)
        XCTAssertNil(state.bgm.duration)
    }

    func testSelectBGMRoutingUsesEnvironmentSpeakerModeDuckedRatio() {
        let item = bgmRuntimeReducerTestItem(title: "Ducked")
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        state.audio.masterVolume = 0.8
        state.audio.bgmVolume = 0.8
        state.audio.isSpeakerMode = true

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedBGM(item.id),
            environment: .productionBGMOwning(
                now: Date(timeIntervalSince1970: 100),
                speakerModeDuckedRatio: 0.2
            )
        )

        XCTAssertEqual(mutation.state.audio.effectiveBGM, 0.16, accuracy: 0.0001)
    }
}
