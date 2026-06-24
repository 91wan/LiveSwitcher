import XCTest
@testable import LiveSwitcher

final class AudioRuntimeReducerBehaviorTests: XCTestCase {
    func testAudioReducerSelectionStillMatchesRoutingEngine() {
        var state = audioState(mediaPlaying: true, bgmPlaying: true)
        state.audio.strategy = .followSource

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedAudioStrategy(.mixed),
            environment: .fullRuntimeForTests(speakerModeDuckedRatio: 0.13)
        )
        let expected = AudioRoutingEngine.output(for: audioInput(from: mutation.state, ratio: 0.13))

        XCTAssertEqual(mutation.state.audio.strategy, .mixed)
        XCTAssertEqual(mutation.state.audio.effectiveMedia, expected.media, accuracy: 0.0001)
        XCTAssertEqual(mutation.state.audio.effectiveBGM, expected.bgm, accuracy: 0.0001)
        XCTAssertEqual(mutation.effects, [
            .applyAudioRouting(reason: .strategyChanged),
            .saveAudioStrategy(.mixed)
        ] as [LiveRuntimeEffect])
    }

    func testAudioReducerClampsVolumesBeforeRouting() {
        let state = audioState(mediaPlaying: true, bgmPlaying: true)

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorChangedMasterVolume(1.4),
            environment: .fullRuntimeForTests()
        )

        XCTAssertEqual(mutation.state.audio.masterVolume, 1)
        XCTAssertEqual(mutation.effects, [.applyAudioRouting(reason: .operatorFaderChanged)])
    }
}

func audioState(mediaPlaying: Bool, bgmPlaying: Bool) -> LiveRuntimeState {
    let video = ProgramItem(
        title: "Opening",
        subtitle: "VIDEO",
        sourceURL: URL(fileURLWithPath: "/tmp/opening.mp4")
    )
    let bgm = BGMItem(
        title: "Walk In",
        url: URL(fileURLWithPath: "/tmp/walk-in.mp3"),
        category: .warmUp
    )
    var state = LiveRuntimeState()
    state.program.items = [video]
    state.program.currentID = video.id
    state.media.loadedURL = video.sourceURL
    state.media.isPlaying = mediaPlaying
    state.bgm.items = [bgm]
    state.bgm.currentID = bgm.id
    state.bgm.phase = bgmPlaying ? .playing : .selected
    state.audio.masterVolume = 0.8
    state.audio.mediaVolume = 0.5
    state.audio.bgmVolume = 0.25
    return state
}

func audioInput(
    from state: LiveRuntimeState,
    ratio: Float = AudioRoutingDefaults.speakerModeDuckedRatio
) -> AudioRoutingInput {
    let context = state.audio.routingContext
    return AudioRoutingInput(
        masterVolume: state.audio.masterVolume,
        mediaVolume: state.audio.mediaVolume,
        bgmVolume: state.audio.bgmVolume,
        audioStrategy: state.audio.strategy,
        isCurrentProgramMediaSource: context.isCurrentProgramMediaSource,
        isMediaPlaying: context.isMediaPlaying,
        isBGMAudioTakeoverActive: state.audio.isBGMTakeoverActive,
        isSpeakerMode: state.audio.isSpeakerMode,
        isPanicMode: context.isPanicMode,
        isMasterMuted: state.audio.isMasterMuted,
        isMediaMuted: state.audio.isMediaMuted,
        isBGMMuted: state.audio.isBGMMuted,
        speakerModeDuckedRatio: ratio
    )
}
