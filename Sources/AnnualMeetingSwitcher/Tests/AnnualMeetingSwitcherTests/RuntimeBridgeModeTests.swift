import XCTest
@testable import LiveSwitcher

final class RuntimeBridgeModeTests: XCTestCase {
    func testBridgeModeCasesAreExplicitAndOrdered() {
        XCTAssertEqual(
            LiveRuntimeBridgeMode.allCases,
            [
                .recordingOnly,
                .audioOwned,
                .mediaOwned,
                .bgmOwned,
                .projectionOwned,
                .fullRuntime
            ]
        )
    }

    func testAudioOwnedModeDoesNotPredictProgramOrMediaStateFromOperatorIntent() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]
        let originalMedia = state.media

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedProgram(item.id),
            environment: LiveRuntimeEnvironment(
                now: Date(timeIntervalSince1970: 100),
                bridgeMode: .audioOwned
            )
        )

        XCTAssertNil(mutation.state.program.currentID)
        XCTAssertNil(mutation.state.program.currentSwitchedAt)
        XCTAssertEqual(mutation.state.media, originalMedia)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testAudioOwnedModeStillOwnsAudioMutationsAndRoutingEffects() {
        var state = LiveRuntimeState()
        state.audio.masterVolume = 1
        state.audio.mediaVolume = 1
        state.media.isPlaying = true
        state.program.currentDetachedItem = mediaProgram()

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorChangedMasterVolume(0.25),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        XCTAssertEqual(mutation.state.audio.masterVolume, 0.25)
        XCTAssertEqual(mutation.state.audio.effectiveMedia, 0.25, accuracy: 0.0001)
        XCTAssertEqual(mutation.effects, [.applyAudioRouting(reason: .operatorFaderChanged)])
    }

    func testAudioOwnedModeStoresFacadeRoutingInputsInsideAudioState() {
        var state = LiveRuntimeState()
        state.media.isPlaying = false
        state.bgm.isPlaying = false
        state.panic.isActive = false

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .facadeAudioInputsChanged(
                AudioFacadeSnapshot(
                    masterVolume: 0.5,
                    mediaVolume: 1,
                    bgmVolume: 0.5,
                    strategy: .mixed,
                    isMasterMuted: false,
                    isMediaMuted: false,
                    isBGMMuted: false,
                    isSpeakerMode: false,
                    isBGMTakeoverActive: false,
                    isPanicMode: true,
                    isCurrentProgramMediaSource: true,
                    isMediaPlaying: true,
                    isBGMPlaying: true
                )
            ),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        XCTAssertEqual(
            mutation.state.audio.routingContext,
            AudioRoutingContext(
                isCurrentProgramMediaSource: true,
                isMediaPlaying: true,
                isBGMPlaying: true,
                isPanicMode: true
            )
        )
        XCTAssertFalse(mutation.state.media.isPlaying)
        XCTAssertFalse(mutation.state.bgm.isPlaying)
        XCTAssertFalse(mutation.state.panic.isActive)
    }

    func testFullRuntimeModeStillEmitsExecutableMediaEffects() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedProgram(item.id),
            environment: LiveRuntimeEnvironment(
                now: Date(timeIntervalSince1970: 100),
                bridgeMode: .fullRuntime
            )
        )

        XCTAssertTrue(mutation.effects.contains(.loadMedia(item.sourceURL!, generation: 1)))
        XCTAssertTrue(mutation.effects.contains(.playMedia(generation: 1)))
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .programChanged)))
    }

    private func mediaProgram() -> ProgramItem {
        ProgramItem(
            title: "Video",
            subtitle: "VIDEO",
            sourceURL: URL(fileURLWithPath: "/tmp/video.mp4")
        )
    }
}
