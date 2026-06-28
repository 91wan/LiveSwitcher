import XCTest
@testable import LiveSwitcher

@MainActor
final class AudioRuntimeSpeakerModeOwnershipTests: XCTestCase {
    func testAudioRoutingUsesAudioRoutingContext() {
        var state = LiveRuntimeState()
        state.audio.routingContext = AudioRoutingContext(
            isCurrentProgramMediaSource: true,
            isMediaPlaying: true,
            isBGMPlaying: true,
            isPanicMode: false
        )
        state.media.isPlaying = false
        state.bgm.phase = .selected
        state.panic.isActive = true

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorChangedMasterVolume(0.5),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        let expected = AudioRoutingEngine.output(
            for: AudioRoutingInput(
                masterVolume: 0.5,
                mediaVolume: state.audio.mediaVolume,
                bgmVolume: state.audio.bgmVolume,
                audioStrategy: state.audio.strategy,
                isCurrentProgramMediaSource: true,
                isMediaPlaying: true,
                isBGMAudioTakeoverActive: state.audio.isBGMTakeoverActive,
                isSpeakerMode: state.audio.isSpeakerMode,
                isPanicMode: false,
                isMasterMuted: state.audio.isMasterMuted,
                isMediaMuted: state.audio.isMediaMuted,
                isBGMMuted: state.audio.isBGMMuted,
                speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
            )
        )

        XCTAssertEqual(mutation.state.audio.effectiveMedia, expected.media, accuracy: 0.0001)
        XCTAssertEqual(mutation.state.audio.effectiveBGM, expected.bgm, accuracy: 0.0001)
    }

    func testMediaCallbackUpdatesRuntimeAudioContextWhenMediaOwned() {
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        try? Data("fixture".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let item = ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: url)
        viewModel.addProgramItem(item)
        viewModel.switchToProgram(item)
        viewModel.runtime.updateEnvironment(LiveRuntimeEnvironment(bridgeMode: .mediaOwned))
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)

        viewModel.dispatchRuntimeMediaCallback {
            .mediaPlaybackChanged(isPlaying: true, generation: $0)
        }

        XCTAssertTrue(viewModel.runtime.state.media.isPlaying)
        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isMediaPlaying)
        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isCurrentProgramMediaSource)
    }
}
