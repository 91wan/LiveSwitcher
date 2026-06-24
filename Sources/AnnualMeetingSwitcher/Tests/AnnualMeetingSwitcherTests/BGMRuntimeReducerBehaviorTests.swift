import XCTest
@testable import LiveSwitcher

final class BGMRuntimeReducerBehaviorTests: XCTestCase {
    func testSelectBGMPreparesPlaysAndStartsTimerWhenPanicInactive() {
        let item = bgmItem(title: "Walk In")
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
        let item = bgmItem(title: "Panic Cue")
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
        let item = bgmItem(title: "Reset")
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
        let item = bgmItem(title: "Ducked")
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

    func testStopBGMUsesLiveAudioFadeDuration() {
        let item = bgmItem(title: "Stop")
        var state = playingState(item: item, generation: 4)
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
        let item = bgmItem(title: "Stop Timer")
        var state = playingState(item: item, generation: 2)
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
        let item = bgmItem(title: "Pause Toggle")
        var state = playingState(item: item, generation: 6)
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
        let item = bgmItem(title: "Resume Toggle")
        var state = pausedState(item: item, generation: 6)
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
        let item = bgmItem(title: "Selected Toggle")
        var state = selectedState(item: item, generation: 6)
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
        let item = bgmItem(title: "Explicit Stop")
        var state = playingState(item: item, generation: 6)
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

    func testPauseBGMForPanicUsesCurrentGenerationWhenNil() {
        let item = bgmItem(title: "Pause")
        var state = playingState(item: item, generation: 6)
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
        let item = bgmItem(title: "Stale Pause")
        var state = playingState(item: item, generation: 6)
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
        let item = bgmItem(title: "Resume")
        var state = panicPausedState(item: item, generation: 9)
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
        let item = bgmItem(title: "Fade Resume")
        var state = panicPausedState(item: item, generation: 9)
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
        let item = bgmItem(title: "Stale Resume")
        var state = stoppedState(item: item, generation: 9)
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

    func testSeekBGMToBeginningResetsProgressAndTime() {
        let item = bgmItem(title: "Seek Start")
        var state = playingState(item: item, generation: 4)
        state.bgm.progress = 0.6
        state.bgm.currentTime = 60
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.seekToBeginning(state: &state, effects: &effects)

        XCTAssertEqual(state.bgm.progress, 0)
        XCTAssertEqual(state.bgm.currentTime, 0)
        XCTAssertTrue(effects.contains(.seekBGMToBeginning(generation: 4)))
    }

    func testSeekBGMToProgressClampsLowValue() {
        let item = bgmItem(title: "Low")
        var state = playingState(item: item, generation: 4)
        state.bgm.duration = 100
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.seekToProgress(-0.2, state: &state, effects: &effects)

        XCTAssertEqual(state.bgm.progress, 0)
        XCTAssertEqual(state.bgm.currentTime, 0)
        XCTAssertTrue(effects.contains(.seekBGMToProgress(0, generation: 4)))
    }

    func testSeekBGMToProgressClampsHighValue() {
        let item = bgmItem(title: "High")
        var state = playingState(item: item, generation: 4)
        state.bgm.duration = 100
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.seekToProgress(1.2, state: &state, effects: &effects)

        XCTAssertEqual(state.bgm.progress, 1)
        XCTAssertEqual(state.bgm.currentTime, 100)
        XCTAssertTrue(effects.contains(.seekBGMToProgress(1, generation: 4)))
    }

    func testSeekBGMToProgressUpdatesCurrentTimeWhenDurationIsKnown() {
        let item = bgmItem(title: "Known Duration")
        var state = playingState(item: item, generation: 4)
        state.bgm.duration = 120
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.seekToProgress(0.25, state: &state, effects: &effects)

        XCTAssertEqual(state.bgm.currentTime, 30)
    }

    func testBGMFailedWritesSupportOnlyWhenAllowed() {
        let item = bgmItem(title: "Failure")
        var allowed = playingState(item: item, generation: 7)
        var denied = playingState(item: item, generation: 7)
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
        let item = bgmItem(title: "Failed Timer")
        var state = playingState(item: item, generation: 7)
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

    func testReachedEndLoopOneRestartsSameBGM() {
        let item = bgmItem(title: "Loop One")
        var state = playingState(item: item, generation: 4)
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
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        var state = playingState(item: first, generation: 4)
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

    func testReplaceLibraryKeepsPlaybackWhenCurrentBGMRemains() {
        let current = bgmItem(title: "Current")
        let added = bgmItem(title: "Added")
        var state = playingState(item: current, generation: 4)
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
        let current = bgmItem(title: "Current")
        let remaining = bgmItem(title: "Remaining")
        var state = playingState(item: current, generation: 4)
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
        let current = bgmItem(title: "Current")
        var state = playingState(item: current, generation: 4)
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
        let item = bgmItem(title: "Ignored")
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

    func testReachedEndLoopAllWrapsToFirstBGM() {
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        var state = playingState(item: second, generation: 4)
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
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        var state = playingState(item: first, generation: 4)
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
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        var state = playingState(item: second, generation: 4)
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
        let item = bgmItem(title: "Missing")
        var state = playingState(item: item, generation: 4)
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
        let warmUp = bgmItem(title: "Warm", category: .warmUp)
        let entrance = bgmItem(title: "Entrance", category: .entrance)
        var state = playingState(item: warmUp, generation: 4)
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

    func testReachedEndStopsWhenPanicActive() {
        let item = bgmItem(title: "Panic Stop")
        var state = playingState(item: item, generation: 4)
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

    private func playingState(item: BGMItem, generation: Int) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        state.bgm.currentID = item.id
        state.bgm.phase = .playing
        state.bgm.generation = generation
        return state
    }

    private func stoppedState(item: BGMItem, generation: Int) -> LiveRuntimeState {
        var state = playingState(item: item, generation: generation)
        state.bgm.phase = .selected
        return state
    }

    private func pausedState(item: BGMItem, generation: Int) -> LiveRuntimeState {
        var state = playingState(item: item, generation: generation)
        state.bgm.phase = .paused
        return state
    }

    private func panicPausedState(item: BGMItem, generation: Int) -> LiveRuntimeState {
        var state = pausedState(item: item, generation: generation)
        state.panic.isActive = true
        state.panic.snapshot = PanicPlaybackSnapshot(
            currentProgramID: nil,
            wasMediaPlaying: false,
            currentBGMID: item.id,
            wasBGMPlaying: true
        )
        return state
    }

    private func selectedState(item: BGMItem, generation: Int) -> LiveRuntimeState {
        var state = playingState(item: item, generation: generation)
        state.bgm.phase = .selected
        return state
    }

    private func bgmItem(title: String, category: BGMCategory = .warmUp) -> BGMItem {
        BGMItem(
            id: UUID(),
            title: title,
            url: URL(fileURLWithPath: "/tmp/\(title).mp3"),
            category: category
        )
    }
}
