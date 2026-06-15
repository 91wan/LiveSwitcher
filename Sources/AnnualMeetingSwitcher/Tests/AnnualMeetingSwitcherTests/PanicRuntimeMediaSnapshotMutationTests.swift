import XCTest
@testable import LiveSwitcher

final class PanicRuntimeMediaSnapshotMutationTests: XCTestCase {
    func testMediaReachedEndDuringPanicClearsRuntimeSnapshotWasMediaPlaying() {
        let mutation = reduce(panicState(), .mediaReachedEnd(generation: 3))

        XCTAssertFalse(mutation.state.panic.snapshot?.wasMediaPlaying == true)
    }

    func testMediaReachedEndOutsidePanicDoesNotMutateSnapshot() {
        var state = panicState()
        state.panic.isActive = false

        let mutation = reduce(state, .mediaReachedEnd(generation: 3))

        XCTAssertTrue(mutation.state.panic.snapshot?.wasMediaPlaying == true)
    }

    func testMediaReachedEndForDifferentCurrentProgramDoesNotMutateSnapshot() {
        var state = panicState()
        let other = ProgramItem(
            id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
            title: "Other",
            subtitle: "MP4",
            sourceURL: URL(fileURLWithPath: "/tmp/other.mp4")
        )
        state.program.items = [other]
        state.program.currentID = other.id

        let mutation = reduce(state, .mediaReachedEnd(generation: 3))

        XCTAssertTrue(mutation.state.panic.snapshot?.wasMediaPlaying == true)
    }

    func testOperatorStoppedCurrentMediaDuringPanicClearsRuntimeSnapshotWasMediaPlaying() {
        let mutation = reduce(panicState(), .operatorStoppedCurrentMedia)

        XCTAssertFalse(mutation.state.panic.snapshot?.wasMediaPlaying == true)
    }

    func testOperatorStoppedCurrentMediaOutsidePanicDoesNotMutateSnapshot() {
        var state = panicState()
        state.panic.isActive = false

        let mutation = reduce(state, .operatorStoppedCurrentMedia)

        XCTAssertTrue(mutation.state.panic.snapshot?.wasMediaPlaying == true)
    }

    func testOperatorPausedMediaForPanicDoesNotClearSnapshotWasMediaPlaying() {
        let mutation = reduce(panicState(), .operatorPausedMediaForPanic(generation: 3))

        XCTAssertTrue(mutation.state.panic.snapshot?.wasMediaPlaying == true)
    }

    func testRestartCurrentMediaDuringPanicDoesNotClearRuntimeSnapshotWasMediaPlaying() {
        let mutation = reduce(panicState(), .operatorRestartedCurrentMedia)

        XCTAssertTrue(mutation.state.panic.snapshot?.wasMediaPlaying == true)
    }

    func testPanicOffDoesNotResumeMediaAfterMediaReachedEndDuringPanic() {
        let ended = reduce(panicState(), .mediaReachedEnd(generation: 3))

        let off = reduce(ended.state, .operatorSetPanic(false))

        XCTAssertFalse(off.state.media.isPlaying)
        XCTAssertFalse(off.effects.contains { if case .playMedia = $0 { return true }; return false })
    }

    func testPanicOffDoesNotResumeMediaAfterOperatorStoppedMediaDuringPanic() {
        let stopped = reduce(panicState(), .operatorStoppedCurrentMedia)

        let off = reduce(stopped.state, .operatorSetPanic(false))

        XCTAssertFalse(off.state.media.isPlaying)
        XCTAssertFalse(off.effects.contains { if case .playMedia = $0 { return true }; return false })
    }

    func testPanicOffStillResumesMediaAfterRestartCurrentMediaDuringPanic() {
        let restarted = reduce(panicState(), .operatorRestartedCurrentMedia)

        let off = reduce(restarted.state, .operatorSetPanic(false))

        XCTAssertTrue(off.state.media.isPlaying)
        XCTAssertTrue(off.effects.contains(.playMedia(generation: 3)))
    }

    func testPanicOffStillResumesMediaAfterPanicPauseOnly() {
        let paused = reduce(panicState(), .operatorPausedMediaForPanic(generation: 3))

        let off = reduce(paused.state, .operatorSetPanic(false))

        XCTAssertTrue(off.state.media.isPlaying)
        XCTAssertTrue(off.effects.contains(.playMedia(generation: 3)))
    }

    private func reduce(_ state: LiveRuntimeState, _ action: LiveRuntimeAction) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: .fullRuntimeForTests(liveAudioFadeDuration: 0)
        )
    }

    private func panicState() -> LiveRuntimeState {
        let program = ProgramItem(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            title: "Video",
            subtitle: "MP4",
            sourceURL: URL(fileURLWithPath: "/tmp/video.mp4")
        )
        var state = LiveRuntimeState()
        state.program.items = [program]
        state.program.currentID = program.id
        state.media.loadedURL = program.sourceURL
        state.media.isPlaying = true
        state.media.generation = 3
        state.panic.isActive = true
        state.panic.snapshot = PanicPlaybackSnapshot(
            currentProgramID: program.id,
            wasMediaPlaying: true,
            currentBGMID: nil,
            wasBGMPlaying: false
        )
        return state
    }
}
