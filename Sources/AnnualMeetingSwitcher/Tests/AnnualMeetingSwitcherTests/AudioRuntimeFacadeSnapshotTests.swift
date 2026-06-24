import XCTest
@testable import LiveSwitcher

final class AudioRuntimeFacadeSnapshotTests: XCTestCase {
    func testFacadeSnapshotUpdatesOnlyAudioAndUsesRoutingContext() {
        var state = LiveRuntimeState()
        state.media.isPlaying = false
        state.bgm.phase = .selected
        state.panic.isActive = false
        let originalMedia = state.media
        let originalBGM = state.bgm
        let originalPanic = state.panic

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .facadeAudioInputsChanged(snapshot()),
            environment: .fullRuntimeForTests(speakerModeDuckedRatio: 0.25)
        )

        XCTAssertEqual(mutation.state.media, originalMedia)
        XCTAssertEqual(mutation.state.bgm, originalBGM)
        XCTAssertEqual(mutation.state.panic, originalPanic)
        XCTAssertEqual(mutation.state.audio.routingContext.isMediaPlaying, true)
        XCTAssertEqual(mutation.state.audio.routingContext.isBGMPlaying, true)
        XCTAssertEqual(mutation.state.audio.routingContext.isPanicMode, false)
        XCTAssertEqual(mutation.state.audio.effectiveMedia, 0.32, accuracy: 0.0001)
        XCTAssertEqual(mutation.state.audio.effectiveBGM, 0.08, accuracy: 0.0001)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    private func snapshot() -> AudioFacadeSnapshot {
        AudioFacadeSnapshot(
            masterVolume: 0.4,
            mediaVolume: 0.8,
            bgmVolume: 0.2,
            strategy: .mixed,
            isMasterMuted: false,
            isMediaMuted: false,
            isBGMMuted: false,
            isSpeakerMode: false,
            isBGMTakeoverActive: false,
            isPanicMode: false,
            isCurrentProgramMediaSource: true,
            isMediaPlaying: true,
            isBGMPlaying: true
        )
    }
}
