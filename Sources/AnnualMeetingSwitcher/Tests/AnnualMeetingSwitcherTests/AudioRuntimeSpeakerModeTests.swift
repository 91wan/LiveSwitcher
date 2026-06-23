import XCTest
@testable import LiveSwitcher

final class AudioRuntimeSpeakerModeTests: XCTestCase {
    func testToggleSpeakerModePersistsAndAppliesSpeakerRouting() {
        var state = audioState(mediaPlaying: true, bgmPlaying: true)
        state.audio.strategy = .mixed

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorToggledSpeakerMode,
            environment: .fullRuntimeForTests(speakerModeDuckedRatio: 0.1)
        )

        XCTAssertTrue(mutation.state.audio.isSpeakerMode)
        XCTAssertEqual(mutation.state.audio.effectiveMedia, 0.08, accuracy: 0.0001)
        XCTAssertEqual(mutation.state.audio.effectiveBGM, 0.08, accuracy: 0.0001)
        XCTAssertEqual(mutation.effects, [
            .applyAudioRouting(reason: .speakerChanged),
            .saveSpeakerMode(true)
        ] as [LiveRuntimeEffect])
    }

    func testSetSpeakerModePersistsRequestedValue() {
        var state = audioState(mediaPlaying: true, bgmPlaying: true)
        state.audio.isSpeakerMode = true

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSetSpeakerMode(false),
            environment: .fullRuntimeForTests()
        )

        XCTAssertFalse(mutation.state.audio.isSpeakerMode)
        XCTAssertEqual(mutation.effects, [
            .applyAudioRouting(reason: .speakerChanged),
            .saveSpeakerMode(false)
        ] as [LiveRuntimeEffect])
    }
}
