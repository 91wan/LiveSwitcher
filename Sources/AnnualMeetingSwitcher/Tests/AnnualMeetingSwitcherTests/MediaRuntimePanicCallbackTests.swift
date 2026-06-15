import XCTest
@testable import LiveSwitcher

final class MediaRuntimePanicCallbackTests: XCTestCase {
    func testMediaPlaybackChangedTrueDuringPanicDoesNotSetMediaPlaying() {
        let mutation = reduce(mediaState(panicActive: true, mediaPlaying: false), .mediaPlaybackChanged(isPlaying: true, generation: 3))

        XCTAssertFalse(mutation.state.media.isPlaying)
    }

    func testMediaPlaybackChangedTrueDuringPanicDoesNotSetRoutingMediaPlaying() {
        let mutation = reduce(mediaState(panicActive: true, mediaPlaying: false), .mediaPlaybackChanged(isPlaying: true, generation: 3))

        XCTAssertFalse(mutation.state.audio.routingContext.isMediaPlaying)
    }

    func testMediaPlaybackChangedTrueDuringPanicEmitsPauseMedia() {
        let mutation = reduce(mediaState(panicActive: true, mediaPlaying: false), .mediaPlaybackChanged(isPlaying: true, generation: 3))

        XCTAssertTrue(mutation.effects.contains(.pauseMedia(generation: 3)))
    }

    func testMediaPlaybackChangedTrueDuringPanicAppliesPanicAudioRouting() {
        let mutation = reduce(mediaState(panicActive: true, mediaPlaying: false), .mediaPlaybackChanged(isPlaying: true, generation: 3))

        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .panicChanged)))
    }

    func testMediaPlaybackChangedTrueDuringPanicDoesNotEmitPlayMedia() {
        let mutation = reduce(mediaState(panicActive: true, mediaPlaying: false), .mediaPlaybackChanged(isPlaying: true, generation: 3))

        XCTAssertFalse(mutation.effects.contains { if case .playMedia = $0 { return true }; return false })
    }

    func testMediaPlaybackChangedTrueDuringPanicDoesNotClearPanicSnapshotWasMediaPlaying() {
        let mutation = reduce(mediaState(panicActive: true, mediaPlaying: false), .mediaPlaybackChanged(isPlaying: true, generation: 3))

        XCTAssertTrue(mutation.state.panic.snapshot?.wasMediaPlaying == true)
    }

    func testMediaPlaybackChangedFalseDuringPanicKeepsMediaNotPlaying() {
        let mutation = reduce(mediaState(panicActive: true, mediaPlaying: true), .mediaPlaybackChanged(isPlaying: false, generation: 3))

        XCTAssertFalse(mutation.state.media.isPlaying)
        XCTAssertFalse(mutation.state.audio.routingContext.isMediaPlaying)
    }

    func testMediaPlaybackChangedFalseDuringPanicAppliesMediaPlaybackRouting() {
        let mutation = reduce(mediaState(panicActive: true, mediaPlaying: true), .mediaPlaybackChanged(isPlaying: false, generation: 3))

        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .mediaPlaybackChanged)))
    }

    func testMediaPlaybackChangedFalseDuringPanicDoesNotClearRuntimeSnapshotWasMediaPlaying() {
        let mutation = reduce(mediaState(panicActive: true, mediaPlaying: true), .mediaPlaybackChanged(isPlaying: false, generation: 3))

        XCTAssertTrue(mutation.state.panic.snapshot?.wasMediaPlaying == true)
    }

    func testMediaPlaybackChangedOutsidePanicAcceptsTrue() {
        let mutation = reduce(mediaState(panicActive: false, mediaPlaying: false), .mediaPlaybackChanged(isPlaying: true, generation: 3))

        XCTAssertTrue(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.state.audio.routingContext.isMediaPlaying)
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .mediaPlaybackChanged)))
    }

    func testMediaPlaybackChangedOutsidePanicAcceptsFalse() {
        let mutation = reduce(mediaState(panicActive: false, mediaPlaying: true), .mediaPlaybackChanged(isPlaying: false, generation: 3))

        XCTAssertFalse(mutation.state.media.isPlaying)
        XCTAssertFalse(mutation.state.audio.routingContext.isMediaPlaying)
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .mediaPlaybackChanged)))
    }

    func testMediaPlaybackChangedIgnoresStaleGenerationDuringPanic() {
        let state = mediaState(panicActive: true, mediaPlaying: false)

        let mutation = reduce(state, .mediaPlaybackChanged(isPlaying: true, generation: 2))

        XCTAssertEqual(mutation.state, state)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testPanicOffStillResumesMediaAfterPlaybackChangedTrueCallbackDuringPanic() {
        let callback = reduce(mediaState(panicActive: true, mediaPlaying: false), .mediaPlaybackChanged(isPlaying: true, generation: 3))

        let off = reduce(callback.state, .operatorSetPanic(false))

        XCTAssertTrue(off.state.media.isPlaying)
        XCTAssertTrue(off.effects.contains(.playMedia(generation: 3)))
    }

    func testPanicOffStillResumesMediaAfterPlaybackChangedFalseDuringPanic() {
        let callback = reduce(mediaState(panicActive: true, mediaPlaying: true), .mediaPlaybackChanged(isPlaying: false, generation: 3))

        let off = reduce(callback.state, .operatorSetPanic(false))

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

    private func mediaState(panicActive: Bool, mediaPlaying: Bool) -> LiveRuntimeState {
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
        state.media.isPlaying = mediaPlaying
        state.media.currentTime = 12
        state.media.duration = 30
        state.media.generation = 3
        state.audio.routingContext.isCurrentProgramMediaSource = true
        state.audio.routingContext.isMediaPlaying = mediaPlaying
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
