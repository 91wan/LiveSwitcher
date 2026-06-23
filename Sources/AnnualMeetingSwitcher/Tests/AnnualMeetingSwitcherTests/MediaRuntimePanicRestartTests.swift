import XCTest
@testable import LiveSwitcher

final class MediaRuntimePanicRestartTests: XCTestCase {
    func testRestartCurrentMediaOutsidePanicEmitsRestartMedia() {
        let mutation = reduce(restartableState(panicActive: false), .operatorRestartedCurrentMedia)

        XCTAssertTrue(mutation.effects.contains(.restartMedia(generation: 3)))
    }

    func testReturnCurrentMediaToStartPausesBeforeSeekingAndDoesNotRestart() {
        let mutation = reduce(restartableState(panicActive: false), .operatorReturnedCurrentMediaToStart)

        XCTAssertEqual(
            mutation.effects.prefix(2),
            [.pauseMedia(generation: 3), .seekMediaToStart(generation: 3)]
        )
        XCTAssertFalse(mutation.effects.contains { if case .restartMedia = $0 { return true }; return false })
        XCTAssertFalse(mutation.effects.contains { if case .playMedia = $0 { return true }; return false })
    }

    func testReturnCurrentMediaToStartLeavesRuntimePausedAtBeginning() {
        let mutation = reduce(restartableState(panicActive: false), .operatorReturnedCurrentMediaToStart)

        XCTAssertFalse(mutation.state.media.isPlaying)
        XCTAssertFalse(mutation.state.media.didPlayToEnd)
        XCTAssertEqual(mutation.state.media.currentTime, 0)
    }

    func testReturnCurrentMediaToStartAppliesAudioRoutingWhenMediaWasPlaying() {
        let mutation = reduce(restartableState(panicActive: false), .operatorReturnedCurrentMediaToStart)

        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .mediaPlaybackChanged)))
        XCTAssertFalse(mutation.state.audio.routingContext.isMediaPlaying)
    }

    func testReturnCurrentMediaToStartDuringPanicPreventsPanicDeactivationResume() {
        let returned = reduce(restartableState(panicActive: true), .operatorReturnedCurrentMediaToStart)

        XCTAssertFalse(returned.state.panic.snapshot?.wasMediaPlaying == true)

        let off = reduce(returned.state, .operatorSetPanic(false))

        XCTAssertFalse(off.state.media.isPlaying)
        XCTAssertFalse(off.effects.contains { if case .playMedia = $0 { return true }; return false })
    }

    func testRestartCurrentMediaOutsidePanicSetsMediaPlayingTrue() {
        let mutation = reduce(restartableState(panicActive: false), .operatorRestartedCurrentMedia)

        XCTAssertTrue(mutation.state.media.isPlaying)
    }

    func testRestartCurrentMediaDuringPanicDoesNotEmitRestartMedia() {
        let mutation = reduce(restartableState(panicActive: true), .operatorRestartedCurrentMedia)

        XCTAssertFalse(mutation.effects.contains { if case .restartMedia = $0 { return true }; return false })
    }

    func testRestartCurrentMediaDuringPanicEmitsSeekMediaToStart() {
        let mutation = reduce(restartableState(panicActive: true), .operatorRestartedCurrentMedia)

        XCTAssertTrue(mutation.effects.contains(.seekMediaToStart(generation: 3)))
    }

    func testRestartCurrentMediaDuringPanicKeepsRuntimeMediaNotPlaying() {
        let mutation = reduce(restartableState(panicActive: true), .operatorRestartedCurrentMedia)

        XCTAssertFalse(mutation.state.media.isPlaying)
    }

    func testRestartCurrentMediaDuringPanicAppliesAudioRouting() {
        let mutation = reduce(restartableState(panicActive: true), .operatorRestartedCurrentMedia)

        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .mediaPlaybackChanged)))
    }

    func testRestartCurrentMediaDuringPanicDoesNotClearPanicSnapshotWasMediaPlaying() {
        let mutation = reduce(restartableState(panicActive: true), .operatorRestartedCurrentMedia)

        XCTAssertTrue(mutation.state.panic.snapshot?.wasMediaPlaying == true)
    }

    func testPanicOffStillResumesMediaAfterRestartDuringPanic() {
        let restarted = reduce(restartableState(panicActive: true), .operatorRestartedCurrentMedia)

        let off = reduce(restarted.state, .operatorSetPanic(false))

        XCTAssertTrue(off.state.media.isPlaying)
        XCTAssertTrue(off.effects.contains(.playMedia(generation: 3)))
    }

    func testRestartCurrentMediaDuringPanicDoesNotEmitPlayMedia() {
        let mutation = reduce(restartableState(panicActive: true), .operatorRestartedCurrentMedia)

        XCTAssertFalse(mutation.effects.contains { if case .playMedia = $0 { return true }; return false })
    }

    func testRestartCurrentMediaStillNoopsForNonSeekingProgram() {
        var state = restartableState(panicActive: true)
        let marker = ProgramItem(title: "Marker", subtitle: "Agenda")
        state.program.items = [marker]
        state.program.currentID = marker.id
        state.media.loadedURL = nil

        let mutation = reduce(state, .operatorRestartedCurrentMedia)

        XCTAssertEqual(mutation.state, state)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    private func reduce(_ state: LiveRuntimeState, _ action: LiveRuntimeAction) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: .fullRuntimeForTests(liveAudioFadeDuration: 0)
        )
    }

    private func restartableState(panicActive: Bool) -> LiveRuntimeState {
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
        state.media.isPlaying = !panicActive
        state.media.didPlayToEnd = true
        state.media.currentTime = 12
        state.media.duration = 30
        state.media.generation = 3
        state.audio.routingContext.isCurrentProgramMediaSource = true
        state.audio.routingContext.isMediaPlaying = !panicActive
        state.panic.isActive = panicActive
        if panicActive {
            state.panic.snapshot = PanicPlaybackSnapshot(
                currentProgramID: program.id,
                wasMediaPlaying: true,
                currentBGMID: nil,
                wasBGMPlaying: false
            )
        }
        return state
    }
}
