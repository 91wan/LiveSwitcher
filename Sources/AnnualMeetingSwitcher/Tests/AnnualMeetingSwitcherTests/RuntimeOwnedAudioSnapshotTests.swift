import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeOwnedAudioSnapshotTests: XCTestCase {
    func testMediaOwnedAudioFacadeSnapshotUsesRuntimeMediaPlaying() {
        let viewModel = makeMediaViewModel(runtimeMediaPlaying: false, avCoordinatorPlaying: true, bridgeMode: .mediaOwned)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertFalse(viewModel.runtime.state.audio.routingContext.isMediaPlaying)
    }

    func testMediaOwnedAudioRoutingContextUsesRuntimeMediaPlaying() {
        let viewModel = makeMediaViewModel(runtimeMediaPlaying: true, avCoordinatorPlaying: false, bridgeMode: .mediaOwned)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isMediaPlaying)
    }

    func testMediaOwnedAudioRoutingContextDoesNotUseStaleAVCoordinatorPlaying() {
        let viewModel = makeMediaViewModel(runtimeMediaPlaying: false, avCoordinatorPlaying: true, bridgeMode: .mediaOwned)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertFalse(viewModel.runtime.state.audio.routingContext.isMediaPlaying)
    }

    func testNonMediaOwnedAudioFacadeSnapshotUsesAVCoordinatorPlaying() {
        let viewModel = makeMediaViewModel(runtimeMediaPlaying: false, avCoordinatorPlaying: true, bridgeMode: .audioOwned)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isMediaPlaying)
    }

    func testNonMediaOwnedAudioRoutingContextUsesAVCoordinatorPlaying() {
        let viewModel = makeMediaViewModel(runtimeMediaPlaying: false, avCoordinatorPlaying: true, bridgeMode: .audioOwned)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isMediaPlaying)
    }

    func testMediaOwnedDispatchDoesNotOverwriteAudioRoutingContextWithStaleAVCoordinatorPlaying() {
        let viewModel = makeMediaViewModel(runtimeMediaPlaying: false, avCoordinatorPlaying: true, bridgeMode: .mediaOwned)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertFalse(viewModel.runtime.state.audio.routingContext.isMediaPlaying)
    }

    private func makeMediaViewModel(
        runtimeMediaPlaying: Bool,
        avCoordinatorPlaying: Bool,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> SwitcherViewModel {
        var state = LiveRuntimeState()
        state.media.isPlaying = runtimeMediaPlaying
        state.audio.routingContext.isMediaPlaying = runtimeMediaPlaying
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, runtime: runtime)
        viewModel.avCoordinator.isPlaying = avCoordinatorPlaying
        return viewModel
    }
}
