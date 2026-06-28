import XCTest
@testable import LiveSwitcher

final class AudioRuntimeReducerExtractionTests: XCTestCase {
    func testAudioFaderActionsClampRecalculateAndEmitRouting() {
        let state = audioState(mediaPlaying: true, bgmPlaying: true)

        let master = reduce(state, .operatorChangedMasterVolume(1.4))
        XCTAssertEqual(master.state.audio.masterVolume, 1, accuracy: 0.0001)
        XCTAssertEqual(master.effects, [.applyAudioRouting(reason: .operatorFaderChanged)])
        assertRoutingMatchesEngine(master.state)

        let media = reduce(state, .operatorChangedMediaVolume(-0.2))
        XCTAssertEqual(media.state.audio.mediaVolume, 0, accuracy: 0.0001)
        XCTAssertEqual(media.effects, [.applyAudioRouting(reason: .operatorFaderChanged)])
        assertRoutingMatchesEngine(media.state)

        let bgm = reduce(state, .operatorChangedBGMVolume(0.7))
        XCTAssertEqual(bgm.state.audio.bgmVolume, 0.7, accuracy: 0.0001)
        XCTAssertEqual(bgm.effects, [.applyAudioRouting(reason: .operatorFaderChanged)])
        assertRoutingMatchesEngine(bgm.state)
    }

    func testAudioMuteActionsRecalculateAndEmitFaderRouting() {
        var state = audioState(mediaPlaying: true, bgmPlaying: true)
        state.audio.strategy = .mixed

        let masterMute = reduce(state, .operatorChangedMasterMute(true))
        XCTAssertTrue(masterMute.state.audio.isMasterMuted)
        XCTAssertEqual(masterMute.state.audio.effectiveMedia, 0, accuracy: 0.0001)
        XCTAssertEqual(masterMute.state.audio.effectiveBGM, 0, accuracy: 0.0001)
        XCTAssertEqual(masterMute.effects, [.applyAudioRouting(reason: .operatorFaderChanged)])

        let mediaMute = reduce(state, .operatorChangedMediaMute(true))
        XCTAssertTrue(mediaMute.state.audio.isMediaMuted)
        XCTAssertEqual(mediaMute.state.audio.effectiveMedia, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(mediaMute.state.audio.effectiveBGM, 0)
        XCTAssertEqual(mediaMute.effects, [.applyAudioRouting(reason: .operatorFaderChanged)])

        let bgmMute = reduce(state, .operatorChangedBGMMute(true))
        XCTAssertTrue(bgmMute.state.audio.isBGMMuted)
        XCTAssertGreaterThan(bgmMute.state.audio.effectiveMedia, 0)
        XCTAssertEqual(bgmMute.state.audio.effectiveBGM, 0, accuracy: 0.0001)
        XCTAssertEqual(bgmMute.effects, [.applyAudioRouting(reason: .operatorFaderChanged)])
    }

    func testSpeakerModeAndBGMTakeoverUseRuntimeRoutingRules() {
        var state = audioState(mediaPlaying: true, bgmPlaying: true)
        state.audio.strategy = .mixed

        let speaker = reduce(
            state,
            .operatorSetSpeakerMode(true),
            environment: .fullRuntimeForTests(speakerModeDuckedRatio: 0.2)
        )
        XCTAssertTrue(speaker.state.audio.isSpeakerMode)
        XCTAssertEqual(speaker.effects, [
            .applyAudioRouting(reason: .speakerChanged),
            .saveSpeakerMode(true)
        ] as [LiveRuntimeEffect])
        assertRoutingMatchesEngine(speaker.state, ratio: 0.2)

        let takeover = reduce(state, .operatorChangedBGMTakeover(true))
        XCTAssertTrue(takeover.state.audio.isBGMTakeoverActive)
        XCTAssertEqual(takeover.state.audio.effectiveMedia, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(takeover.state.audio.effectiveBGM, 0)
        XCTAssertEqual(takeover.effects, [.applyAudioRouting(reason: .limiterChanged)])
    }

    func testPanicRoutingForcesSilentEffectiveOutput() {
        let mutation = reduce(
            audioState(mediaPlaying: true, bgmPlaying: true),
            .operatorSetPanic(true),
            environment: .fullRuntimeForTests(liveAudioFadeDuration: 0)
        )

        XCTAssertTrue(mutation.state.panic.isActive)
        XCTAssertTrue(mutation.state.audio.routingContext.isPanicMode)
        XCTAssertEqual(mutation.state.audio.effectiveMedia, 0, accuracy: 0.0001)
        XCTAssertEqual(mutation.state.audio.effectiveBGM, 0, accuracy: 0.0001)
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .panicChanged)))
    }

    func testFacadeAudioSnapshotAppliesMirrorInputsWithoutEmittingEffects() {
        let snapshot = AudioFacadeSnapshot(
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

        let mutation = reduce(
            LiveRuntimeState(),
            .facadeAudioInputsChanged(snapshot),
            environment: .fullRuntimeForTests(speakerModeDuckedRatio: 0.25)
        )

        XCTAssertEqual(mutation.state.audio.routingContext.isCurrentProgramMediaSource, true)
        XCTAssertEqual(mutation.state.audio.routingContext.isMediaPlaying, true)
        XCTAssertEqual(mutation.state.audio.routingContext.isBGMPlaying, true)
        XCTAssertEqual(mutation.state.audio.effectiveMedia, 0.32, accuracy: 0.0001)
        XCTAssertEqual(mutation.state.audio.effectiveBGM, 0.08, accuracy: 0.0001)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testAudioActionsNoopWhenAudioBridgeIsNotRuntimeOwned() {
        let state = audioState(mediaPlaying: true, bgmPlaying: true)

        let mutation = reduce(
            state,
            .operatorChangedMasterVolume(0.2),
            environment: .recordingOnlyForTests()
        )

        XCTAssertEqual(mutation.state, state)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction,
        environment: LiveRuntimeEnvironment = .fullRuntimeForTests()
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(state: state, action: action, environment: environment)
    }

    private func assertRoutingMatchesEngine(
        _ state: LiveRuntimeState,
        ratio: Float = AudioRoutingDefaults.speakerModeDuckedRatio,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expected = AudioRoutingEngine.output(for: audioInput(from: state, ratio: ratio))
        XCTAssertEqual(state.audio.effectiveMedia, expected.media, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(state.audio.effectiveBGM, expected.bgm, accuracy: 0.0001, file: file, line: line)
    }
}
