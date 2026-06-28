import XCTest
@testable import LiveSwitcher

final class BGMRuntimeReducerExtractionTests: XCTestCase {
    func testSelectionStartsRequestedBGMAndEmitsPlaybackEffects() {
        let first = item("First")
        let second = item("Second")
        var state = LiveRuntimeState()
        state.bgm.items = [first, second]

        let mutation = reduce(state, .operatorSelectedBGM(second.id))

        XCTAssertEqual(mutation.state.bgm.currentID, second.id)
        XCTAssertEqual(mutation.state.bgm.phase, .playing)
        XCTAssertEqual(mutation.state.bgm.generation, 1)
        XCTAssertEqual(mutation.state.bgm.progress, 0)
        XCTAssertEqual(mutation.effects, [
            .prepareBGM(second, generation: 1),
            .playBGM(generation: 1),
            .startBGMTimer(generation: 1),
            .applyAudioRouting(reason: .bgmPlaybackChanged)
        ] as [LiveRuntimeEffect])
    }

    func testToggleSeekProgressAndStopMutatePlaybackState() {
        let cue = item("Cue")
        let started = reduce(
            bgmRuntimeReducerTestSelectedState(item: cue, generation: 6),
            .operatorToggledCurrentBGMPlayback
        )
        XCTAssertEqual(started.state.bgm.phase, .playing)
        XCTAssertEqual(started.state.bgm.generation, 7)
        XCTAssertTrue(started.effects.contains(.prepareBGM(cue, generation: 7)))
        XCTAssertTrue(started.effects.contains(.startBGMTimer(generation: 7)))

        let paused = reduce(started.state, .operatorToggledCurrentBGMPlayback)
        XCTAssertEqual(paused.state.bgm.phase, .paused)
        XCTAssertEqual(paused.state.bgm.generation, 7)
        XCTAssertTrue(paused.effects.contains(.pauseBGM(generation: 7)))
        XCTAssertTrue(paused.effects.contains(.stopBGMTimer(generation: 7)))

        var progressState = started.state
        progressState.bgm.duration = 40
        let progressed = reduce(progressState, .bgmProgressUpdated(time: 10, duration: 40, generation: 7))
        XCTAssertEqual(progressed.state.bgm.currentTime, 10, accuracy: 0.0001)
        XCTAssertEqual(progressed.state.bgm.progress, 0.25, accuracy: 0.0001)
        XCTAssertTrue(progressed.effects.isEmpty)

        let stopped = reduce(
            progressed.state,
            .operatorStoppedBGM,
            environment: .productionBGMOwning(liveAudioFadeDuration: 0.35)
        )
        XCTAssertEqual(stopped.state.bgm.phase, .selected)
        XCTAssertEqual(stopped.state.bgm.generation, 8)
        XCTAssertEqual(stopped.state.bgm.progress, 0)
        XCTAssertEqual(stopped.state.bgm.currentTime, 0)
        XCTAssertNil(stopped.state.bgm.duration)
        XCTAssertTrue(stopped.effects.contains(.stopBGM(fade: 0.35, generation: 8)))
        XCTAssertTrue(stopped.effects.contains(.stopBGMTimer(generation: 8)))
    }

    func testReachedEndHonorsLoopOneAndSequentialModes() {
        let first = item("First")
        let second = item("Second")

        let loopOne = reduce(
            playingState(items: [first, second], current: first, playMode: .loopOne),
            .bgmReachedEnd(generation: 4)
        )
        XCTAssertEqual(loopOne.state.bgm.currentID, first.id)
        XCTAssertEqual(loopOne.state.bgm.phase, .playing)
        XCTAssertTrue(loopOne.effects.contains(.prepareBGM(first, generation: 5)))

        let sequentialNext = reduce(
            playingState(items: [first, second], current: first, playMode: .sequential),
            .bgmReachedEnd(generation: 4)
        )
        XCTAssertEqual(sequentialNext.state.bgm.currentID, second.id)
        XCTAssertEqual(sequentialNext.state.bgm.phase, .playing)
        XCTAssertTrue(sequentialNext.effects.contains(.prepareBGM(second, generation: 5)))

        let sequentialEnd = reduce(
            playingState(items: [first, second], current: second, playMode: .sequential),
            .bgmReachedEnd(generation: 4)
        )
        XCTAssertEqual(sequentialEnd.state.bgm.currentID, second.id)
        XCTAssertEqual(sequentialEnd.state.bgm.phase, .selected)
        XCTAssertTrue(sequentialEnd.effects.contains(.stopBGM(fade: 0, generation: 5)))
    }

    func testAdjacentSelectionStaysWithinCurrentCategory() {
        let first = item("First", category: .warmUp)
        let second = item("Second", category: .warmUp)
        let otherCategory = item("Other", category: .ambient)
        var state = playingState(items: [first, otherCategory, second], current: first, playMode: .loopAll)

        let next = reduce(state, .operatorSelectedNextBGM)
        XCTAssertEqual(next.state.bgm.currentID, second.id)
        XCTAssertTrue(next.effects.contains(.prepareBGM(second, generation: 5)))

        state = next.state
        let previous = reduce(state, .operatorSelectedPreviousBGM)
        XCTAssertEqual(previous.state.bgm.currentID, first.id)
        XCTAssertTrue(previous.effects.contains(.prepareBGM(first, generation: 6)))
    }

    func testLibraryReplacementStopsRemovedCurrentAndNoopsWithoutOwnership() {
        let current = item("Current")
        let remaining = item("Remaining")
        var state = bgmRuntimeReducerTestPlayingState(item: current, generation: 3)
        state.bgm.items = [current, remaining]

        let notOwned = reduce(
            state,
            .facadeBGMLibraryChanged([remaining]),
            environment: .recordingOnlyForTests()
        )
        XCTAssertEqual(notOwned.state, state)
        XCTAssertTrue(notOwned.effects.isEmpty)

        let owned = reduce(
            state,
            .facadeBGMLibraryChanged([remaining]),
            environment: .productionBGMOwning(liveAudioFadeDuration: 1.25)
        )
        XCTAssertEqual(owned.state.bgm.items, [remaining])
        XCTAssertNil(owned.state.bgm.currentID)
        XCTAssertEqual(owned.state.bgm.phase, .idle)
        XCTAssertEqual(owned.state.bgm.generation, 4)
        XCTAssertTrue(owned.effects.contains(.stopBGM(fade: 1.25, generation: 4)))
        XCTAssertTrue(owned.effects.contains(.applyAudioRouting(reason: .bgmPlaybackChanged)))
    }

    func testPanicPauseResumeRespectGenerationAndFadeInOrder() {
        let cue = item("Panic")
        let stalePause = reduce(
            bgmRuntimeReducerTestPlayingState(item: cue, generation: 6),
            .operatorPausedBGMForPanic(generation: 5)
        )
        XCTAssertEqual(stalePause.state.bgm.phase, .playing)
        XCTAssertTrue(stalePause.effects.isEmpty)

        let pause = reduce(
            bgmRuntimeReducerTestPlayingState(item: cue, generation: 6),
            .operatorPausedBGMForPanic(generation: nil)
        )
        XCTAssertEqual(pause.state.bgm.phase, .paused)
        XCTAssertTrue(pause.effects.contains(.pauseBGM(generation: 6)))
        XCTAssertTrue(pause.effects.contains(.applyAudioRouting(reason: .panicChanged)))

        let resume = reduce(
            bgmRuntimeReducerTestPanicPausedState(item: cue, generation: 6),
            .operatorResumedBGMAfterPanic(generation: nil)
        )
        XCTAssertEqual(resume.state.bgm.phase, .playing)
        XCTAssertEqual(Array(resume.effects.prefix(3)), [
            .setBGMVolume(0, fade: 0, generation: 6),
            .playBGM(generation: 6),
            .startBGMTimer(generation: 6)
        ] as [LiveRuntimeEffect])
    }

    func testPlayModePersistsAndUsesCurrentGenerationWhenPresent() {
        let cue = item("Mode")
        var state = bgmRuntimeReducerTestSelectedState(item: cue, generation: 8)

        let withCurrent = reduce(state, .operatorSelectedBGMPlayMode(.loopOne))
        XCTAssertEqual(withCurrent.state.bgm.playMode, .loopOne)
        XCTAssertEqual(withCurrent.effects, [
            .setBGMPlayMode(.loopOne, generation: 8),
            .saveBGMPlayMode(.loopOne)
        ] as [LiveRuntimeEffect])

        state.bgm.currentID = nil
        let withoutCurrent = reduce(state, .operatorSelectedBGMPlayMode(.sequential))
        XCTAssertEqual(withoutCurrent.effects, [
            .setBGMPlayMode(.sequential, generation: nil),
            .saveBGMPlayMode(.sequential)
        ] as [LiveRuntimeEffect])
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction,
        environment: LiveRuntimeEnvironment = .productionBGMOwning()
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(state: state, action: action, environment: environment)
    }

    private func playingState(
        items: [BGMItem],
        current: BGMItem,
        playMode: BGMPlayMode
    ) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.bgm.items = items
        state.bgm.currentID = current.id
        state.bgm.phase = .playing
        state.bgm.playMode = playMode
        state.bgm.generation = 4
        return state
    }

    private func item(_ title: String, category: BGMCategory = .warmUp) -> BGMItem {
        bgmRuntimeReducerTestItem(title: title, category: category)
    }
}
