import XCTest
@testable import LiveSwitcher

final class MediaRuntimePanicGateTests: XCTestCase {
    func testToggleMediaDuringPanicWhenStoppedDoesNotEmitPlayMedia() {
        let mutation = reduce(mediaState(panicActive: true, mediaPlaying: false), .operatorToggledMediaPlayback)

        XCTAssertFalse(mutation.effects.contains { if case .playMedia = $0 { return true }; return false })
    }

    func testToggleMediaDuringPanicWhenStoppedNoops() {
        let state = mediaState(panicActive: true, mediaPlaying: false)

        let mutation = reduce(state, .operatorToggledMediaPlayback)

        XCTAssertEqual(mutation.state, state)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testToggleMediaDuringPanicWhenPlayingEmitsPauseMedia() {
        let mutation = reduce(mediaState(panicActive: true, mediaPlaying: true), .operatorToggledMediaPlayback)

        XCTAssertTrue(mutation.effects.contains(.pauseMedia(generation: 3)))
    }

    func testToggleMediaDuringPanicWhenPlayingSetsMediaNotPlaying() {
        let mutation = reduce(mediaState(panicActive: true, mediaPlaying: true), .operatorToggledMediaPlayback)

        XCTAssertFalse(mutation.state.media.isPlaying)
    }

    func testToggleMediaDuringPanicWhenPlayingAppliesPanicAudioRouting() {
        let mutation = reduce(mediaState(panicActive: true, mediaPlaying: true), .operatorToggledMediaPlayback)

        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .panicChanged)))
    }

    func testToggleMediaDuringPanicDoesNotClearPanicSnapshotWasMediaPlaying() {
        let mutation = reduce(mediaState(panicActive: true, mediaPlaying: true), .operatorToggledMediaPlayback)

        XCTAssertTrue(mutation.state.panic.snapshot?.wasMediaPlaying == true)
    }

    func testPanicOffStillResumesMediaAfterTogglePauseDuringPanic() {
        let paused = reduce(mediaState(panicActive: true, mediaPlaying: true), .operatorToggledMediaPlayback)

        let off = reduce(paused.state, .operatorSetPanic(false))

        XCTAssertTrue(off.state.media.isPlaying)
        XCTAssertTrue(off.effects.contains(.playMedia(generation: 3)))
    }

    func testToggleMediaOutsidePanicStillEmitsPlayWhenStopped() {
        let mutation = reduce(mediaState(panicActive: false, mediaPlaying: false), .operatorToggledMediaPlayback)

        XCTAssertTrue(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.effects.contains(.playMedia(generation: 3)))
    }

    func testToggleMediaOutsidePanicStillEmitsPauseWhenPlaying() {
        let mutation = reduce(mediaState(panicActive: false, mediaPlaying: true), .operatorToggledMediaPlayback)

        XCTAssertFalse(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.effects.contains(.pauseMedia(generation: 3)))
    }

    func testToggleMediaStillNoopsWhenDidPlayToEnd() {
        var state = mediaState(panicActive: true, mediaPlaying: false)
        state.media.didPlayToEnd = true

        let mutation = reduce(state, .operatorToggledMediaPlayback)

        XCTAssertEqual(mutation.state, state)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testResumeMediaAfterPanicNoopsWhenPanicStillActive() {
        let state = mediaState(panicActive: true, mediaPlaying: false)

        let mutation = reduce(state, .operatorResumedMediaAfterPanic(generation: 3))

        XCTAssertEqual(mutation.state, state)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testResumeMediaAfterPanicDoesNotEmitPlayMediaWhenPanicStillActive() {
        let mutation = reduce(mediaState(panicActive: true, mediaPlaying: false), .operatorResumedMediaAfterPanic(generation: 3))

        XCTAssertFalse(mutation.effects.contains { if case .playMedia = $0 { return true }; return false })
    }

    func testResumeMediaAfterPanicWorksWhenPanicInactive() {
        let mutation = reduce(mediaState(panicActive: false, mediaPlaying: false), .operatorResumedMediaAfterPanic(generation: 3))

        XCTAssertTrue(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.effects.contains(.playMedia(generation: 3)))
    }

    func testResumeMediaAfterPanicStillSetsVolumeZeroBeforePlayWhenInactive() throws {
        let effects = reduce(mediaState(panicActive: false, mediaPlaying: false), .operatorResumedMediaAfterPanic(generation: 3)).effects

        let volumeIndex = try XCTUnwrap(effects.firstIndex(of: .setMediaVolume(0, fade: 0, generation: 3)))
        let playIndex = try XCTUnwrap(effects.firstIndex(of: .playMedia(generation: 3)))
        XCTAssertLessThan(volumeIndex, playIndex)
    }

    func testSelectingMediaProgramDuringPanicLoadsButDoesNotPlay() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]
        state.panic.isActive = true

        let mutation = reduce(state, .operatorSelectedProgram(item.id))

        XCTAssertTrue(mutation.effects.contains(.loadMedia(item.sourceURL!, generation: 1)))
        XCTAssertFalse(mutation.state.media.isPlaying)
    }

    func testSelectingMediaProgramDuringPanicDoesNotEmitPlayMedia() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]
        state.panic.isActive = true

        let mutation = reduce(state, .operatorSelectedProgram(item.id))

        XCTAssertFalse(mutation.effects.contains { if case .playMedia = $0 { return true }; return false })
    }

    func testSelectingMediaProgramOutsidePanicStillLoadsAndPlays() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]

        let mutation = reduce(state, .operatorSelectedProgram(item.id))

        XCTAssertTrue(mutation.effects.contains(.loadMedia(item.sourceURL!, generation: 1)))
        XCTAssertTrue(mutation.effects.contains(.playMedia(generation: 1)))
    }

    private func reduce(_ state: LiveRuntimeState, _ action: LiveRuntimeAction) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: .fullRuntimeForTests(liveAudioFadeDuration: 0)
        )
    }

    private func mediaState(panicActive: Bool, mediaPlaying: Bool) -> LiveRuntimeState {
        let program = mediaProgram()
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

    private func mediaProgram() -> ProgramItem {
        ProgramItem(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            title: "Video",
            subtitle: "MP4",
            sourceURL: URL(fileURLWithPath: "/tmp/video.mp4")
        )
    }
}
