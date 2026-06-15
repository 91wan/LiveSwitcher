import XCTest
@testable import LiveSwitcher

final class PanicRuntimeBGMSnapshotMutationTests: XCTestCase {
    func testBGMReachedEndDuringPanicClearsRuntimeSnapshotWasBGMPlaying() {
        let mutation = reduce(panicState(), .bgmReachedEnd(generation: 7))

        XCTAssertFalse(mutation.state.panic.snapshot?.wasBGMPlaying == true)
    }

    func testBGMFailedDuringPanicClearsRuntimeSnapshotWasBGMPlaying() {
        let mutation = reduce(panicState(), .bgmFailed(reason: "playbackFailed", generation: 7))

        XCTAssertFalse(mutation.state.panic.snapshot?.wasBGMPlaying == true)
    }

    func testOperatorStoppedBGMDuringPanicClearsRuntimeSnapshotWasBGMPlaying() {
        let mutation = reduce(panicState(), .operatorStoppedBGM)

        XCTAssertFalse(mutation.state.panic.snapshot?.wasBGMPlaying == true)
    }

    func testOperatorSelectedNewBGMDuringPanicClearsOldRuntimeSnapshotWasBGMPlaying() {
        var state = panicState()
        let next = BGMItem(
            id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
            title: "Next",
            url: URL(fileURLWithPath: "/tmp/next.mp3")
        )
        state.bgm.items.append(next)

        let mutation = reduce(state, .operatorSelectedBGM(next.id))

        XCTAssertFalse(mutation.state.panic.snapshot?.wasBGMPlaying == true)
    }

    func testOperatorPausedBGMForPanicDoesNotClearSnapshotWasBGMPlaying() {
        let mutation = reduce(panicState(), .operatorPausedBGMForPanic(generation: 7))

        XCTAssertTrue(mutation.state.panic.snapshot?.wasBGMPlaying == true)
    }

    func testPanicOffDoesNotResumeBGMAfterBGMReachedEndDuringPanic() {
        let ended = reduce(panicState(), .bgmReachedEnd(generation: 7))

        let off = reduce(ended.state, .operatorSetPanic(false))

        XCTAssertFalse(off.state.bgm.isPlaying)
        XCTAssertFalse(off.effects.contains { if case .playBGM = $0 { return true }; return false })
    }

    func testPanicOffDoesNotResumeBGMAfterBGMFailedDuringPanic() {
        let failed = reduce(panicState(), .bgmFailed(reason: "playbackFailed", generation: 7))

        let off = reduce(failed.state, .operatorSetPanic(false))

        XCTAssertFalse(off.state.bgm.isPlaying)
        XCTAssertFalse(off.effects.contains { if case .playBGM = $0 { return true }; return false })
    }

    func testPanicOffDoesNotResumeBGMAfterOperatorStoppedBGMDuringPanic() {
        let stopped = reduce(panicState(), .operatorStoppedBGM)

        let off = reduce(stopped.state, .operatorSetPanic(false))

        XCTAssertFalse(off.state.bgm.isPlaying)
        XCTAssertFalse(off.effects.contains { if case .playBGM = $0 { return true }; return false })
    }

    func testPanicOffStillResumesBGMAfterPanicPauseOnly() {
        let paused = reduce(panicState(), .operatorPausedBGMForPanic(generation: 7))

        let off = reduce(paused.state, .operatorSetPanic(false))

        XCTAssertTrue(off.state.bgm.isPlaying)
        XCTAssertTrue(off.effects.contains(.playBGM(generation: 7)))
    }

    private func reduce(_ state: LiveRuntimeState, _ action: LiveRuntimeAction) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: .fullRuntimeForTests(liveAudioFadeDuration: 0)
        )
    }

    private func panicState() -> LiveRuntimeState {
        let bgm = BGMItem(
            id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
            title: "Walk In",
            url: URL(fileURLWithPath: "/tmp/walk-in.mp3")
        )
        var state = LiveRuntimeState()
        state.bgm.items = [bgm]
        state.bgm.currentID = bgm.id
        state.bgm.isPlaying = true
        state.bgm.generation = 7
        state.panic.isActive = true
        state.panic.snapshot = PanicPlaybackSnapshot(
            currentProgramID: nil,
            wasMediaPlaying: false,
            currentBGMID: bgm.id,
            wasBGMPlaying: true
        )
        return state
    }
}
