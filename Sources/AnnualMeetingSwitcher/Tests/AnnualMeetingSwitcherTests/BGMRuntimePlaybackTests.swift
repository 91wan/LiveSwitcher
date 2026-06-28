import XCTest
@testable import LiveSwitcher

final class BGMRuntimeReducerPlaybackTests: XCTestCase {
    func testStopBGMUsesLiveAudioFadeDuration() {
        let item = bgmRuntimeReducerTestItem(title: "Stop")
        var state = bgmRuntimeReducerTestPlayingState(item: item, generation: 4)
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.stop(
            state: &state,
            effects: &effects,
            liveAudioFadeDuration: 1.25,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertFalse(state.bgm.isPlaying)
        XCTAssertTrue(effects.contains(.stopBGM(fade: 1.25, generation: 5)))
    }

    func testStopBGMStopsTimer() {
        let item = bgmRuntimeReducerTestItem(title: "Stop Timer")
        var state = bgmRuntimeReducerTestPlayingState(item: item, generation: 2)
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.stop(
            state: &state,
            effects: &effects,
            liveAudioFadeDuration: 0.4,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertTrue(effects.contains(.stopBGMTimer(generation: 3)))
    }

    func testToggleCurrentBGMFromPlayingPausesWithoutResettingPlaybackIdentity() {
        let item = bgmRuntimeReducerTestItem(title: "Pause Toggle")
        var state = bgmRuntimeReducerTestPlayingState(item: item, generation: 6)
        state.bgm.progress = 0.42
        state.bgm.currentTime = 42
        state.bgm.duration = 100

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorToggledCurrentBGMPlayback,
            environment: .productionBGMOwning()
        )

        XCTAssertEqual(mutation.state.bgm.phase, .paused)
        XCTAssertEqual(mutation.state.bgm.generation, 6)
        XCTAssertEqual(mutation.state.bgm.currentID, item.id)
        XCTAssertEqual(mutation.state.bgm.progress, 0.42)
        XCTAssertEqual(mutation.state.bgm.currentTime, 42)
        XCTAssertEqual(mutation.state.bgm.duration, 100)
        XCTAssertTrue(mutation.effects.contains(.pauseBGM(generation: 6)))
        XCTAssertTrue(mutation.effects.contains(.stopBGMTimer(generation: 6)))
        XCTAssertFalse(mutation.effects.contains(.prepareBGM(item, generation: 6)))
        XCTAssertFalse(mutation.effects.contains(.stopBGM(fade: AudioRoutingDefaults.liveAudioFadeDuration, generation: 7)))
    }

    func testToggleCurrentBGMFromPausedResumesWithoutPreparingOrResettingProgress() {
        let item = bgmRuntimeReducerTestItem(title: "Resume Toggle")
        var state = bgmRuntimeReducerTestPausedState(item: item, generation: 6)
        state.bgm.progress = 0.42
        state.bgm.currentTime = 42
        state.bgm.duration = 100

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorToggledCurrentBGMPlayback,
            environment: .productionBGMOwning()
        )

        XCTAssertEqual(mutation.state.bgm.phase, .playing)
        XCTAssertEqual(mutation.state.bgm.generation, 6)
        XCTAssertEqual(mutation.state.bgm.progress, 0.42)
        XCTAssertEqual(mutation.state.bgm.currentTime, 42)
        XCTAssertEqual(mutation.state.bgm.duration, 100)
        XCTAssertTrue(mutation.effects.contains(.playBGM(generation: 6)))
        XCTAssertTrue(mutation.effects.contains(.startBGMTimer(generation: 6)))
        XCTAssertFalse(mutation.effects.contains(.prepareBGM(item, generation: 6)))
        XCTAssertFalse(mutation.effects.contains(.seekBGMToBeginning(generation: 6)))
    }

    func testToggleCurrentBGMFromSelectedStartsFreshGeneration() {
        let item = bgmRuntimeReducerTestItem(title: "Selected Toggle")
        var state = bgmRuntimeReducerTestSelectedState(item: item, generation: 6)
        state.bgm.progress = 0.42
        state.bgm.currentTime = 42
        state.bgm.duration = 100

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorToggledCurrentBGMPlayback,
            environment: .productionBGMOwning()
        )

        XCTAssertEqual(mutation.state.bgm.phase, .playing)
        XCTAssertEqual(mutation.state.bgm.generation, 7)
        XCTAssertEqual(mutation.state.bgm.progress, 0)
        XCTAssertEqual(mutation.state.bgm.currentTime, 0)
        XCTAssertNil(mutation.state.bgm.duration)
        XCTAssertTrue(mutation.effects.contains(.prepareBGM(item, generation: 7)))
        XCTAssertTrue(mutation.effects.contains(.playBGM(generation: 7)))
        XCTAssertTrue(mutation.effects.contains(.startBGMTimer(generation: 7)))
    }

    func testExplicitStopKeepsSelectionButResetsPlaybackPosition() {
        let item = bgmRuntimeReducerTestItem(title: "Explicit Stop")
        var state = bgmRuntimeReducerTestPlayingState(item: item, generation: 6)
        state.bgm.progress = 0.42
        state.bgm.currentTime = 42
        state.bgm.duration = 100

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorStoppedBGM,
            environment: .productionBGMOwning()
        )

        XCTAssertEqual(mutation.state.bgm.phase, .selected)
        XCTAssertEqual(mutation.state.bgm.generation, 7)
        XCTAssertEqual(mutation.state.bgm.currentID, item.id)
        XCTAssertEqual(mutation.state.bgm.progress, 0)
        XCTAssertEqual(mutation.state.bgm.currentTime, 0)
        XCTAssertNil(mutation.state.bgm.duration)
        XCTAssertTrue(mutation.effects.contains(.stopBGM(fade: AudioRoutingDefaults.liveAudioFadeDuration, generation: 7)))
        XCTAssertTrue(mutation.effects.contains(.stopBGMTimer(generation: 7)))
    }

    func testBGMFailedWritesSupportOnlyWhenAllowed() {
        let item = bgmRuntimeReducerTestItem(title: "Failure")
        var allowed = bgmRuntimeReducerTestPlayingState(item: item, generation: 7)
        var denied = bgmRuntimeReducerTestPlayingState(item: item, generation: 7)
        var allowedEffects: [LiveRuntimeEffect] = []
        var deniedEffects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.failed(
            reason: "decode",
            generation: 7,
            state: &allowed,
            effects: &allowedEffects,
            canWriteSupport: true,
            now: Date(timeIntervalSince1970: 100),
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )
        BGMRuntimeReducer.failed(
            reason: "decode",
            generation: 7,
            state: &denied,
            effects: &deniedEffects,
            canWriteSupport: false,
            now: Date(timeIntervalSince1970: 100),
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertEqual(allowed.support.events.last?.kind, .bgmPlaybackFailed)
        XCTAssertTrue(denied.support.events.isEmpty)
    }

    func testBGMFailedStopsTimerAndAppliesAudioRouting() {
        let item = bgmRuntimeReducerTestItem(title: "Failed Timer")
        var state = bgmRuntimeReducerTestPlayingState(item: item, generation: 7)
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.failed(
            reason: "decode",
            generation: 7,
            state: &state,
            effects: &effects,
            canWriteSupport: false,
            now: Date(timeIntervalSince1970: 100),
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertTrue(effects.contains(.stopBGMTimer(generation: 8)))
        XCTAssertTrue(effects.contains(.applyAudioRouting(reason: .bgmPlaybackChanged)))
    }
}
