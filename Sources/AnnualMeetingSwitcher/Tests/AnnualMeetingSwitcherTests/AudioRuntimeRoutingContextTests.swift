import XCTest
@testable import LiveSwitcher

final class AudioRuntimeRoutingContextTests: XCTestCase {
    func testSyncRoutingContextFromMirrorStateCopiesPlaybackFlags() {
        var state = audioState(mediaPlaying: true, bgmPlaying: false)
        state.panic.isActive = true

        AudioRuntimeReducer.syncRoutingContextFromMirrorState(&state)

        XCTAssertEqual(
            state.audio.routingContext,
            AudioRoutingContext(
                isCurrentProgramMediaSource: true,
                isMediaPlaying: true,
                isBGMPlaying: false,
                isPanicMode: true
            )
        )
    }

    func testRecalculateInitializesEmptyRoutingContextFromMirrorStateWhenNeeded() {
        var state = audioState(mediaPlaying: true, bgmPlaying: true)
        state.audio.routingContext = AudioRoutingContext()

        AudioRuntimeReducer.recalculateAudio(&state)

        XCTAssertTrue(state.audio.routingContext.isMediaPlaying)
        XCTAssertTrue(state.audio.routingContext.isBGMPlaying)
        XCTAssertGreaterThan(state.audio.effectiveMedia, 0)
        XCTAssertGreaterThan(state.audio.effectiveBGM, 0)
    }
}
