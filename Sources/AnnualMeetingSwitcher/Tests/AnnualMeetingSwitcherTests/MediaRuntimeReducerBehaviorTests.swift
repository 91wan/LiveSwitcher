import XCTest
@testable import LiveSwitcher

final class MediaRuntimeReducerBehaviorTests: XCTestCase {
    func testTogglePlaybackPausesPlayingMediaAndAppliesRouting() {
        var state = mediaState(mediaPlaying: true)
        state.media.didPlayToEnd = false
        var effects: [LiveRuntimeEffect] = []

        MediaRuntimeReducer.togglePlayback(
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertFalse(state.media.isPlaying)
        XCTAssertFalse(state.audio.routingContext.isMediaPlaying)
        XCTAssertTrue(effects.contains(.pauseMedia(generation: 3)))
        XCTAssertTrue(effects.contains(.applyAudioRouting(reason: .mediaPlaybackChanged)))
    }

    func testRestartCurrentResetsEndedMediaAndStartsPlayback() {
        var state = mediaState(mediaPlaying: false)
        var effects: [LiveRuntimeEffect] = []

        MediaRuntimeReducer.restartCurrent(
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertFalse(state.media.didPlayToEnd)
        XCTAssertEqual(state.media.currentTime, 0)
        XCTAssertTrue(state.media.isPlaying)
        XCTAssertTrue(effects.contains(.restartMedia(generation: 3)))
        XCTAssertTrue(effects.contains(.applyAudioRouting(reason: .mediaPlaybackChanged)))
    }

    func testSeekCurrentToEndUsesKnownDuration() {
        var state = mediaState()
        var effects: [LiveRuntimeEffect] = []

        MediaRuntimeReducer.seekCurrentToEnd(state: &state, effects: &effects)

        XCTAssertFalse(state.media.didPlayToEnd)
        XCTAssertEqual(state.media.currentTime, 30)
        XCTAssertTrue(effects.contains(.seekMediaToEnd(generation: 3)))
    }

    func testStopCurrentClearsLoadedMediaAndAdvancesGeneration() {
        var state = mediaState(mediaPlaying: true)
        var effects: [LiveRuntimeEffect] = []

        MediaRuntimeReducer.stopCurrent(
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertNil(state.media.loadedURL)
        XCTAssertFalse(state.media.isPlaying)
        XCTAssertFalse(state.media.didPlayToEnd)
        XCTAssertEqual(state.media.currentTime, 0)
        XCTAssertNil(state.media.duration)
        XCTAssertEqual(state.media.generation, 4)
        XCTAssertTrue(effects.contains(.stopMedia(generation: 4)))
        XCTAssertTrue(effects.contains(.applyAudioRouting(reason: .mediaPlaybackChanged)))
    }

    func testPauseForPanicPausesMatchingGenerationAndAppliesPanicRouting() {
        var state = mediaState(mediaPlaying: true)
        state.media.didPlayToEnd = false
        var effects: [LiveRuntimeEffect] = []

        MediaRuntimeReducer.pauseForPanic(
            generation: 3,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertFalse(state.media.isPlaying)
        XCTAssertFalse(state.audio.routingContext.isMediaPlaying)
        XCTAssertTrue(effects.contains(.pauseMedia(generation: 3)))
        XCTAssertTrue(effects.contains(.applyAudioRouting(reason: .panicChanged)))
    }

    func testResumeAfterPanicRestartsMediaFromMutedVolume() {
        var state = mediaState(mediaPlaying: false)
        state.media.didPlayToEnd = true
        state.panic.isActive = false
        var effects: [LiveRuntimeEffect] = []

        MediaRuntimeReducer.resumeAfterPanic(
            generation: 3,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertTrue(state.media.isPlaying)
        XCTAssertFalse(state.media.didPlayToEnd)
        XCTAssertTrue(effects.contains(.setMediaVolume(0, fade: 0, generation: 3)))
        XCTAssertTrue(effects.contains(.playMedia(generation: 3)))
        XCTAssertTrue(effects.contains(.applyAudioRouting(reason: .panicChanged)))
    }

    func testMediaLoadedStoresURLWhenGenerationMatches() {
        var state = mediaState()
        let url = URL(fileURLWithPath: "/tmp/new-video.mp4")

        MediaRuntimeReducer.loaded(url: url, generation: 3, state: &state)

        XCTAssertEqual(state.media.loadedURL, url)
        XCTAssertFalse(state.media.didPlayToEnd)
    }

    func testMediaLoadedIgnoresStaleGeneration() {
        var state = mediaState()
        let originalURL = state.media.loadedURL

        MediaRuntimeReducer.loaded(url: URL(fileURLWithPath: "/tmp/stale.mp4"), generation: 2, state: &state)

        XCTAssertEqual(state.media.loadedURL, originalURL)
        XCTAssertTrue(state.media.didPlayToEnd)
    }

    func testMediaPlaybackChangedUpdatesPlayingWhenGenerationMatches() {
        var state = mediaState(mediaPlaying: false)
        var effects: [LiveRuntimeEffect] = []

        MediaRuntimeReducer.playbackChanged(
            isPlaying: true,
            generation: 3,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertTrue(state.media.isPlaying)
        XCTAssertTrue(state.audio.routingContext.isMediaPlaying)
        XCTAssertTrue(effects.contains(.applyAudioRouting(reason: .mediaPlaybackChanged)))
    }

    func testMediaPlaybackChangedIgnoresStaleGeneration() {
        var state = mediaState(mediaPlaying: false)
        var effects: [LiveRuntimeEffect] = []

        MediaRuntimeReducer.playbackChanged(
            isPlaying: true,
            generation: 2,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertFalse(state.media.isPlaying)
        XCTAssertTrue(effects.isEmpty)
    }

    func testMediaReachedEndSetsDidPlayToEnd() {
        var state = mediaState(mediaPlaying: true)
        var effects: [LiveRuntimeEffect] = []

        MediaRuntimeReducer.reachedEnd(
            generation: 3,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertTrue(state.media.didPlayToEnd)
    }

    func testMediaReachedEndSetsMediaNotPlaying() {
        var state = mediaState(mediaPlaying: true)
        var effects: [LiveRuntimeEffect] = []

        MediaRuntimeReducer.reachedEnd(
            generation: 3,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertFalse(state.media.isPlaying)
        XCTAssertFalse(state.audio.routingContext.isMediaPlaying)
    }

    func testMediaReachedEndAppliesAudioRouting() {
        var state = mediaState(mediaPlaying: true)
        var effects: [LiveRuntimeEffect] = []

        MediaRuntimeReducer.reachedEnd(
            generation: 3,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertTrue(effects.contains(.applyAudioRouting(reason: .mediaPlaybackChanged)))
    }

    func testMediaReachedEndMarksPanicSnapshotMediaStopped() {
        var state = mediaState(mediaPlaying: true, panicActive: true)
        var effects: [LiveRuntimeEffect] = []

        MediaRuntimeReducer.reachedEnd(
            generation: 3,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertFalse(state.panic.snapshot?.wasMediaPlaying == true)
    }

    func testMediaSeekCompletedUpdatesCurrentTime() {
        var state = mediaState()

        MediaRuntimeReducer.seekCompleted(time: 42, generation: 3, state: &state)

        XCTAssertEqual(state.media.currentTime, 42)
    }

    func testMediaSeekCompletedIgnoresStaleGeneration() {
        var state = mediaState()

        MediaRuntimeReducer.seekCompleted(time: 42, generation: 2, state: &state)

        XCTAssertEqual(state.media.currentTime, 12)
    }

    private func mediaState(
        mediaPlaying: Bool = true,
        panicActive: Bool = false
    ) -> LiveRuntimeState {
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
        state.media.didPlayToEnd = true
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
