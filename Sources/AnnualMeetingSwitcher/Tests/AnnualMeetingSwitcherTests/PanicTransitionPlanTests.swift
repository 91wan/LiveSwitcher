import XCTest
@testable import LiveSwitcher

final class PanicTransitionPlanTests: XCTestCase {
    private let programID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let bgmID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    func testActivationCapturesProgramBGMIDsAndPlaybackFlags() {
        for (mediaPlaying, bgmPlaying) in [(true, false), (false, true)] {
            let state = inputsState(isMediaPlaying: mediaPlaying, isBGMPlaying: bgmPlaying)

            let mutation = reduce(state, isActive: true)

            XCTAssertTrue(mutation.state.panic.isActive)
            XCTAssertEqual(mutation.state.panic.snapshot, PanicPlaybackSnapshot(
                currentProgramID: programID,
                wasMediaPlaying: mediaPlaying,
                currentBGMID: bgmID,
                wasBGMPlaying: bgmPlaying
            ))
        }
    }

    func testActivationPausesMediaImmediatelyAndSchedulesBGMPauseAfterFade() {
        let state = inputsState(isMediaPlaying: true, isBGMPlaying: true)
        let expectedSnapshot = PanicPlaybackSnapshot(
            currentProgramID: programID,
            wasMediaPlaying: true,
            currentBGMID: bgmID,
            wasBGMPlaying: true
        )

        let mutation = reduce(state, isActive: true, fadeDuration: 0.75)

        XCTAssertFalse(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.state.bgm.isPlaying)
        XCTAssertEqual(mutation.state.panic.generation, 5)
        XCTAssertEqual(mutation.effects, [
            .pauseMedia(generation: 13),
            .schedulePanicBGMPause(generation: 5, snapshot: expectedSnapshot, delay: 0.75),
            .applyAudioRouting(reason: .panicChanged)
        ])
    }

    func testDeactivationResumesOnlyEligiblePlaybackAndRequiresSnapshot() {
        let scenarios: [(snapshot: PanicPlaybackSnapshot?, media: Bool, bgm: Bool, playbackEffects: [LiveRuntimeEffect])] = [
            (PanicPlaybackSnapshot(
                currentProgramID: programID,
                wasMediaPlaying: true,
                currentBGMID: bgmID,
                wasBGMPlaying: false
            ), true, false, [.playMedia(generation: 13)]),
            (PanicPlaybackSnapshot(
                currentProgramID: programID,
                wasMediaPlaying: false,
                currentBGMID: bgmID,
                wasBGMPlaying: true
            ), false, true, [.playBGM(generation: 29), .startBGMTimer(generation: 29)]),
            (nil, false, false, [])
        ]

        for scenario in scenarios {
            var state = inputsState(isMediaPlaying: false, isBGMPlaying: false)
            state.panic.isActive = true
            state.panic.snapshot = scenario.snapshot

            let mutation = reduce(state, isActive: false)

            XCTAssertFalse(mutation.state.panic.isActive)
            XCTAssertNil(mutation.state.panic.snapshot)
            XCTAssertEqual(mutation.state.panic.generation, 5)
            XCTAssertEqual(mutation.state.media.isPlaying, scenario.media)
            XCTAssertEqual(mutation.state.bgm.isPlaying, scenario.bgm)
            let expectedEffects: [LiveRuntimeEffect] = [.cancelPanicBGMPause(generation: 4)]
                + scenario.playbackEffects
                + [.applyAudioRouting(reason: .panicChanged)]
            XCTAssertEqual(mutation.effects, expectedEffects)
        }
    }

    private func inputsState(isMediaPlaying: Bool, isBGMPlaying: Bool) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.program.items = [ProgramItem(
            id: programID,
            title: "Video",
            subtitle: "MP4",
            sourceURL: URL(fileURLWithPath: "/tmp/panic-video.mp4")
        )]
        state.program.currentID = programID
        state.media.isPlaying = isMediaPlaying
        state.media.generation = 13
        state.bgm.items = [BGMItem(
            id: bgmID,
            title: "Background",
            url: URL(fileURLWithPath: "/tmp/panic-background.mp3")
        )]
        state.bgm.currentID = bgmID
        state.bgm.phase = isBGMPlaying ? .playing : .paused
        state.bgm.generation = 29
        state.panic.generation = 4
        return state
    }

    private func reduce(
        _ state: LiveRuntimeState,
        isActive: Bool,
        fadeDuration: Double = 0.75
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSetPanic(isActive),
            environment: .productionPanicOwning(liveAudioFadeDuration: fadeDuration)
        )
    }
}
