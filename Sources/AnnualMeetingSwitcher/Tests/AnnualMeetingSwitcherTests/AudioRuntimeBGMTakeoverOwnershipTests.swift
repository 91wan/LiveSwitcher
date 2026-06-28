import XCTest
@testable import LiveSwitcher

@MainActor
final class AudioRuntimeBGMTakeoverOwnershipTests: XCTestCase {
    func testFacadeAudioInputsChangedDoesNotMutateBGMState() {
        var state = LiveRuntimeState()
        state.bgm.currentID = UUID()
        state.bgm.phase = .selected
        state.bgm.progress = 0.4
        let originalBGM = state.bgm

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .facadeAudioInputsChanged(audioRuntimeOwnershipSnapshot(bgmPlaying: true)),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        XCTAssertEqual(mutation.state.bgm, originalBGM)
    }

    func testEffectiveBGMOutputGetterDoesNotDispatchAction() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        var runtimeState = runtime.state
        runtimeState.audio.bgmVolume = 0.1
        runtimeState.audio.effectiveBGM = 0.31
        runtime.replaceStateForFacadeSync(runtimeState, clearActionLog: true)

        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.31, accuracy: 0.0001)
        XCTAssertTrue(runtime.actionLog.isEmpty)
    }

    func testBGMCallbackUpdatesRuntimeAudioContextWhenBGMOwned() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .bgmOwned)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        let item = BGMItem(title: "BGM", url: URL(fileURLWithPath: "/tmp/audio-runtime-bgm.mp3"))
        viewModel.bgmItems = [item]
        viewModel.currentBGMItem = item
        viewModel.seedActiveRuntimeBGMCallbackForTesting(item: item, generation: 0)
        var runtimeState = runtime.state
        runtimeState.bgm.items = [item]
        runtimeState.bgm.currentID = item.id
        runtimeState.bgm.generation = 0
        runtime.replaceStateForFacadeSync(runtimeState, clearActionLog: true)
        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        viewModel.dispatchRuntimeBGMCallback {
            .bgmPlaybackChanged(isPlaying: true, generation: $0)
        }

        XCTAssertTrue(runtime.state.bgm.isPlaying)
        XCTAssertTrue(runtime.state.audio.routingContext.isBGMPlaying)
    }

    func testEffectiveBGMOutputReadsRuntimeStateWithoutLegacyRecompute() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        var runtimeState = runtime.state
        runtimeState.audio.effectiveMedia = 0.17
        runtimeState.audio.effectiveBGM = 0.23
        runtime.replaceStateForFacadeSync(runtimeState)

        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.23, accuracy: 0.0001)
    }
}
