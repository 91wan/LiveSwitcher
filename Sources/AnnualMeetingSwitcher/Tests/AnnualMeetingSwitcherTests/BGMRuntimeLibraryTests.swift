import XCTest
@testable import LiveSwitcher

final class BGMRuntimeReducerLibraryTests: XCTestCase {
    func testReplaceLibraryKeepsPlaybackWhenCurrentBGMRemains() {
        let current = bgmRuntimeReducerTestItem(title: "Current")
        let added = bgmRuntimeReducerTestItem(title: "Added")
        var state = bgmRuntimeReducerTestPlayingState(item: current, generation: 4)
        state.bgm.progress = 0.4
        state.bgm.currentTime = 12
        state.bgm.duration = 30
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.replaceLibrary(
            [added, current],
            state: &state,
            effects: &effects,
            liveAudioFadeDuration: 1,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertEqual(state.bgm.items.map(\.id), [added.id, current.id])
        XCTAssertEqual(state.bgm.currentID, current.id)
        XCTAssertTrue(state.bgm.isPlaying)
        XCTAssertEqual(state.bgm.generation, 4)
        XCTAssertEqual(state.bgm.progress, 0.4)
        XCTAssertEqual(state.bgm.currentTime, 12)
        XCTAssertEqual(state.bgm.duration, 30)
        XCTAssertTrue(effects.isEmpty)
    }

    func testReplaceLibraryClearsCurrentBGMWhenRemoved() {
        let current = bgmRuntimeReducerTestItem(title: "Current")
        let remaining = bgmRuntimeReducerTestItem(title: "Remaining")
        var state = bgmRuntimeReducerTestPlayingState(item: current, generation: 4)
        state.bgm.items = [current, remaining]
        state.bgm.progress = 0.4
        state.bgm.currentTime = 12
        state.bgm.duration = 30
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.replaceLibrary(
            [remaining],
            state: &state,
            effects: &effects,
            liveAudioFadeDuration: 1.25,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertEqual(state.bgm.items.map(\.id), [remaining.id])
        XCTAssertNil(state.bgm.currentID)
        XCTAssertFalse(state.bgm.isPlaying)
        XCTAssertEqual(state.bgm.generation, 5)
        XCTAssertEqual(state.bgm.progress, 0)
        XCTAssertEqual(state.bgm.currentTime, 0)
        XCTAssertNil(state.bgm.duration)
        XCTAssertTrue(effects.contains(.stopBGM(fade: 1.25, generation: 5)))
        XCTAssertTrue(effects.contains(.stopBGMTimer(generation: 5)))
        XCTAssertTrue(effects.contains(.applyAudioRouting(reason: .bgmPlaybackChanged)))
    }

    func testReplaceLibraryMarksPanicSnapshotStoppedAndRecalculatesAudio() {
        let current = bgmRuntimeReducerTestItem(title: "Current")
        var state = bgmRuntimeReducerTestPlayingState(item: current, generation: 4)
        state.panic.isActive = true
        state.panic.snapshot = PanicPlaybackSnapshot(
            currentProgramID: nil,
            wasMediaPlaying: false,
            currentBGMID: current.id,
            wasBGMPlaying: true
        )
        state.audio.masterVolume = 0.8
        state.audio.bgmVolume = 0.5
        state.audio.routingContext.isBGMPlaying = true
        state.audio.effectiveBGM = 0.99
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.replaceLibrary(
            [],
            state: &state,
            effects: &effects,
            liveAudioFadeDuration: 0,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertFalse(state.panic.snapshot?.wasBGMPlaying ?? true)
        XCTAssertFalse(state.audio.routingContext.isBGMPlaying)
        XCTAssertEqual(state.audio.effectiveBGM, 0, accuracy: 0.0001)
    }

    func testReplaceLibraryRequiresBGMOwnershipThroughRuntimeReducer() {
        let item = bgmRuntimeReducerTestItem(title: "Ignored")
        var state = LiveRuntimeState()

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .facadeBGMLibraryChanged([item]),
            environment: .recordingOnlyForTests()
        )
        state.bgm.items = [item]
        let owned = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .facadeBGMLibraryChanged([item]),
            environment: .productionBGMOwning()
        )

        XCTAssertTrue(mutation.state.bgm.items.isEmpty)
        XCTAssertEqual(owned.state.bgm.items, [item])
    }

    @MainActor
    func testFacadeBGMLibraryChangedIsNotLoggedAndDoesNotLeakTitlesOrURLs() {
        let item = BGMItem(
            title: "Private Walk In",
            url: URL(fileURLWithPath: "/tmp/private-walk-in.mp3")
        )
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .bgmOwned)
        )

        runtime.dispatch(.facadeBGMLibraryChanged([item]))

        XCTAssertFalse(LiveRuntimeActionLogPolicy.shouldLog(.facadeBGMLibraryChanged([item])))
        XCTAssertTrue(runtime.actionLog.isEmpty)
    }

    func testFacadeBGMLibraryChangedOnlySyncsBGMFacade() {
        let options = LiveRuntimeFacadeSyncPolicy.options(for: .facadeBGMLibraryChanged([]))

        XCTAssertFalse(options.dispatchAudioInputsChanged)
        XCTAssertTrue(options.syncBGM)
        XCTAssertFalse(options.syncProjection)
        XCTAssertFalse(options.syncPPT)
        XCTAssertFalse(options.syncAutomationNotice)
        XCTAssertFalse(options.syncSupport)
        XCTAssertFalse(options.syncProgramQueue)
        XCTAssertFalse(options.syncCurrentProgram)
        XCTAssertFalse(options.syncPanic)
    }
}
