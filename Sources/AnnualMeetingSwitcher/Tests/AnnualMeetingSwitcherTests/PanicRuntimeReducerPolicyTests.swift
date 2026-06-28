import XCTest
@testable import LiveSwitcher

@MainActor
final class PanicRuntimeReducerPolicyTests: XCTestCase {
    func testPanicRuntimeReducerUsesTransitionPolicy() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/PanicRuntimeReducer.swift")

        XCTAssertTrue(source.contains("PanicTransitionPolicy.snapshot"))
        XCTAssertTrue(source.contains("PanicTransitionPolicy.shouldPauseMediaForActivation"))
        XCTAssertTrue(source.contains("PanicTransitionPolicy.shouldPauseBGMAfterFadeForActivation"))
        XCTAssertTrue(source.contains("PanicTransitionPolicy.shouldResumeMediaAfterDeactivation"))
        XCTAssertTrue(source.contains("PanicTransitionPolicy.shouldResumeBGMAfterDeactivation"))
    }

    func testLiveRuntimeReducerDelegatesPanicToPanicRuntimeReducer() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/Reducers/PanicProjectionRuntimeActionDispatcher.swift"
        )

        XCTAssertTrue(source.contains("PanicRuntimeReducer.setPanic"))
        XCTAssertTrue(source.contains("PanicRuntimeReducer.bgmPauseDelayElapsed"))
        XCTAssertFalse(source.contains("reducePanicToggle"))
    }

    func testActivationCapturesPanicSnapshot() {
        let state = activeInputsState()
        let expected = PanicTransitionPolicy.snapshot(
            currentProgram: state.program.effectiveCurrentItem,
            isMediaPlaying: state.media.isPlaying,
            currentBGM: state.bgm.currentItem,
            isBGMPlaying: state.bgm.isPlaying
        )

        let mutation = reduce(state, .operatorSetPanic(true), fadeDuration: 0.5)

        XCTAssertTrue(mutation.state.panic.isActive)
        XCTAssertEqual(mutation.state.panic.snapshot, expected)
    }

    func testActivationPausesMatchingMediaImmediately() {
        let state = activeInputsState()

        let mutation = reduce(state, .operatorSetPanic(true), fadeDuration: 0.5)

        XCTAssertFalse(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.effects.contains(.pauseMedia(generation: state.media.generation)))
    }

    func testActivationDoesNotPauseNonMatchingMedia() {
        var state = activeInputsState()
        state.program.currentID = nil

        let mutation = reduce(state, .operatorSetPanic(true), fadeDuration: 0.5)

        XCTAssertTrue(mutation.state.media.isPlaying)
        XCTAssertFalse(mutation.effects.contains(where: { effect in
            if case .pauseMedia = effect { return true }
            return false
        }))
    }

    func testActivationSchedulesBGMWhenFadeDurationIsPositive() {
        let state = activeInputsState()

        let mutation = reduce(state, .operatorSetPanic(true), fadeDuration: 0.5)

        XCTAssertTrue(mutation.state.bgm.isPlaying)
        XCTAssertTrue(mutation.effects.contains(where: { effect in
            if case .schedulePanicBGMPause(let generation, let snapshot, let delay) = effect {
                return generation == mutation.state.panic.generation
                    && snapshot == mutation.state.panic.snapshot
                    && delay == 0.5
            }
            return false
        }))
        XCTAssertFalse(mutation.effects.contains(where: { effect in
            if case .pauseBGM = effect { return true }
            return false
        }))
    }

    func testActivationPausesBGMImmediatelyWhenFadeDurationIsZero() {
        let state = activeInputsState()

        let mutation = reduce(state, .operatorSetPanic(true), fadeDuration: 0)

        XCTAssertFalse(mutation.state.bgm.isPlaying)
        XCTAssertTrue(mutation.effects.contains(.pauseBGM(generation: state.bgm.generation)))
    }

    func testDeactivationCancelsDelayedBGMPauseForPreviousGeneration() {
        let state = panicActiveState()

        let mutation = reduce(state, .operatorSetPanic(false), fadeDuration: 0.5)

        XCTAssertFalse(mutation.state.panic.isActive)
        XCTAssertNil(mutation.state.panic.snapshot)
        XCTAssertEqual(mutation.state.panic.generation, state.panic.generation + 1)
        XCTAssertTrue(mutation.effects.contains(.cancelPanicBGMPause(generation: state.panic.generation)))
    }

    func testDeactivationResumesMatchingMediaAndBGM() {
        let state = panicActiveState()

        let mutation = reduce(state, .operatorSetPanic(false), fadeDuration: 0.5)

        XCTAssertTrue(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.state.bgm.isPlaying)
        XCTAssertTrue(mutation.effects.contains(.playMedia(generation: state.media.generation)))
        XCTAssertTrue(mutation.effects.contains(.playBGM(generation: state.bgm.generation)))
    }

    func testDeactivationDoesNotResumeDifferentMediaOrBGM() {
        var state = panicActiveState()
        let otherProgram = mediaProgram(
            id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
            title: "Changed"
        )
        let otherBGM = BGMItem(id: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!, title: "Changed", url: URL(fileURLWithPath: "/tmp/changed.mp3"))
        state.program.items = [otherProgram]
        state.program.currentID = otherProgram.id
        state.bgm.items = [otherBGM]
        state.bgm.currentID = otherBGM.id

        let mutation = reduce(state, .operatorSetPanic(false), fadeDuration: 0.5)

        XCTAssertFalse(mutation.state.media.isPlaying)
        XCTAssertFalse(mutation.state.bgm.isPlaying)
        XCTAssertFalse(mutation.effects.contains(where: { effect in
            if case .playMedia = effect { return true }
            return false
        }))
        XCTAssertFalse(mutation.effects.contains(where: { effect in
            if case .playBGM = effect { return true }
            return false
        }))
    }

    func testPanicReducerDoesNotWriteSupport() {
        let state = activeInputsState()

        let mutation = reduce(state, .operatorSetPanic(true), fadeDuration: 0.5)

        XCTAssertTrue(mutation.state.support.events.isEmpty)
        XCTAssertFalse(mutation.effects.contains(where: { effect in
            if case .recordSupportEvent = effect { return true }
            return false
        }))
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction,
        fadeDuration: Double
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: .fullRuntimeForTests(liveAudioFadeDuration: fadeDuration)
        )
    }

    private func activeInputsState() -> LiveRuntimeState {
        let program = mediaProgram()
        let bgm = bgmItem()
        var state = LiveRuntimeState()
        state.program.items = [program]
        state.program.currentID = program.id
        state.media.isPlaying = true
        state.media.generation = 3
        state.bgm.items = [bgm]
        state.bgm.currentID = bgm.id
        state.bgm.phase = .playing
        state.bgm.generation = 9
        return state
    }

    private func panicActiveState() -> LiveRuntimeState {
        let program = mediaProgram()
        let bgm = bgmItem()
        var state = LiveRuntimeState()
        state.program.items = [program]
        state.program.currentID = program.id
        state.media.generation = 3
        state.bgm.items = [bgm]
        state.bgm.currentID = bgm.id
        state.bgm.generation = 9
        state.panic.isActive = true
        state.panic.generation = 5
        state.panic.snapshot = PanicPlaybackSnapshot(
            currentProgramID: program.id,
            wasMediaPlaying: true,
            currentBGMID: bgm.id,
            wasBGMPlaying: true
        )
        return state
    }

    private func mediaProgram(
        id: UUID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
        title: String = "Video"
    ) -> ProgramItem {
        ProgramItem(
            id: id,
            title: title,
            subtitle: "MP4",
            sourceURL: URL(fileURLWithPath: "/tmp/\(title).mp4")
        )
    }

    private func bgmItem() -> BGMItem {
        BGMItem(
            id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
            title: "Walk In",
            url: URL(fileURLWithPath: "/tmp/walk-in.mp3")
        )
    }
}
