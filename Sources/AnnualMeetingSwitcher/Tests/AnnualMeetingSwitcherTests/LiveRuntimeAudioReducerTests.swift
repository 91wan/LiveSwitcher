import XCTest
@testable import LiveSwitcher

final class LiveRuntimeAudioReducerTests: XCTestCase {
    func testRuntimeEffectiveVolumesMatchAudioRoutingEngineForCoreStrategies() {
        let cases: [(AudioStrategy, Bool, Bool)] = [
            (.mixed, true, false),
            (.followProgram, true, false),
            (.followSource, true, false),
            (.bgmOnly, true, false),
            (.mixed, true, true)
        ]

        for (strategy, mediaPlaying, speakerMode) in cases {
            var state = baseState(mediaPlaying: mediaPlaying, bgmPlaying: true)
            state.audio.strategy = strategy
            state.audio.isSpeakerMode = speakerMode

            let environment = LiveRuntimeEnvironment.fullRuntimeForTests(
                now: Date(timeIntervalSince1970: 100),
                speakerModeDuckedRatio: 0.11
            )
            let mutation = LiveRuntimeReducer.reduce(
                state: state,
                action: .operatorSelectedAudioStrategy(strategy),
                environment: environment
            )
            let expected = AudioRoutingEngine.output(for: audioInput(from: mutation.state, ratio: 0.11))

            XCTAssertEqual(mutation.state.audio.effectiveMedia, expected.media, accuracy: 0.0001, "strategy=\(strategy)")
            XCTAssertEqual(mutation.state.audio.effectiveBGM, expected.bgm, accuracy: 0.0001, "strategy=\(strategy)")
        }
    }

    func testRuntimeEffectiveVolumesMatchAudioRoutingEngineForPanicAndTakeover() {
        var state = baseState(mediaPlaying: true, bgmPlaying: true)
        let panic = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSetPanic(true),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )
        XCTAssertEqual(panic.state.audio.effectiveMedia, 0, accuracy: 0.0001)
        XCTAssertEqual(panic.state.audio.effectiveBGM, 0, accuracy: 0.0001)

        state = baseState(mediaPlaying: true, bgmPlaying: true)
        let takeover = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorChangedBGMTakeover(true),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )
        let expected = AudioRoutingEngine.output(for: audioInput(from: takeover.state))
        XCTAssertEqual(takeover.state.audio.effectiveMedia, expected.media, accuracy: 0.0001)
        XCTAssertEqual(takeover.state.audio.effectiveBGM, expected.bgm, accuracy: 0.0001)
        XCTAssertEqual(takeover.state.audio.effectiveMedia, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(takeover.state.audio.effectiveBGM, 0)
    }

    func testSpeakerModeDuckedRatioComesFromRuntimeEnvironment() {
        var state = baseState(mediaPlaying: true, bgmPlaying: true)
        state.audio.isSpeakerMode = true

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSetSpeakerMode(true),
            environment: .fullRuntimeForTests(
                now: Date(timeIntervalSince1970: 100),
                speakerModeDuckedRatio: 0.2
            )
        )

        XCTAssertEqual(mutation.state.audio.effectiveMedia, 0.16, accuracy: 0.0001)
        XCTAssertEqual(mutation.state.audio.effectiveBGM, 0.16, accuracy: 0.0001)
    }

    private func baseState(mediaPlaying: Bool, bgmPlaying: Bool) -> LiveRuntimeState {
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
        state.bgm.isPlaying = bgmPlaying
        state.audio.masterVolume = 0.8
        state.audio.mediaVolume = 0.5
        state.audio.bgmVolume = 0.25
        return state
    }

    private func audioInput(
        from state: LiveRuntimeState,
        ratio: Float = AudioRoutingDefaults.speakerModeDuckedRatio
    ) -> AudioRoutingInput {
        AudioRoutingInput(
            masterVolume: state.audio.masterVolume,
            mediaVolume: state.audio.mediaVolume,
            bgmVolume: state.audio.bgmVolume,
            audioStrategy: state.audio.strategy,
            isCurrentProgramMediaSource: state.program.currentItem?.sourceKind == .media,
            isMediaPlaying: state.media.isPlaying,
            isBGMAudioTakeoverActive: state.audio.isBGMTakeoverActive,
            isSpeakerMode: state.audio.isSpeakerMode,
            isPanicMode: state.panic.isActive,
            isMasterMuted: state.audio.isMasterMuted,
            isMediaMuted: state.audio.isMediaMuted,
            isBGMMuted: state.audio.isBGMMuted,
            speakerModeDuckedRatio: ratio
        )
    }
}
