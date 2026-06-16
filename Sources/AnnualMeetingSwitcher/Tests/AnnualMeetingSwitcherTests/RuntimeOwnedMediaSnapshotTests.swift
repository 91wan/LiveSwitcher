import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeOwnedMediaSnapshotTests: XCTestCase {
    func testMediaOwnedSnapshotPreservesRuntimeLoadedURL() {
        let runtimeURL = mediaURL("runtime.mp4")
        let staleURL = mediaURL("stale.mp4")
        let viewModel = makeViewModel(runtimeState: runtimeMediaState(url: runtimeURL), bridgeMode: .mediaOwned)
        viewModel.avCoordinator.load(url: staleURL)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertEqual(viewModel.runtime.state.media.loadedURL, runtimeURL)
    }

    func testMediaOwnedSnapshotPreservesRuntimeIsPlaying() {
        var state = runtimeMediaState(url: mediaURL("runtime.mp4"))
        state.media.isPlaying = false
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .mediaOwned)
        viewModel.avCoordinator.isPlaying = true

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertFalse(viewModel.runtime.state.media.isPlaying)
    }

    func testMediaOwnedSnapshotPreservesRuntimeCurrentTime() {
        var state = runtimeMediaState(url: mediaURL("runtime.mp4"))
        state.media.currentTime = 42
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .mediaOwned)
        viewModel.avCoordinator.currentTime = 7

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertEqual(viewModel.runtime.state.media.currentTime, 42)
    }

    func testMediaOwnedSnapshotPreservesRuntimeDuration() {
        var state = runtimeMediaState(url: mediaURL("runtime.mp4"))
        state.media.duration = 120
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .mediaOwned)
        viewModel.avCoordinator.duration = 5

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertEqual(viewModel.runtime.state.media.duration, 120)
    }

    func testMediaOwnedSnapshotPreservesRuntimeGeneration() {
        var state = runtimeMediaState(url: mediaURL("runtime.mp4"))
        state.media.generation = 9
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .mediaOwned)
        viewModel.avCoordinator.load(url: mediaURL("stale.mp4"))

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertEqual(viewModel.runtime.state.media.generation, 9)
    }

    func testMediaOwnedSnapshotDoesNotOverwriteRuntimeMediaWithAVCoordinatorState() {
        let runtimeURL = mediaURL("runtime.mp4")
        let staleURL = mediaURL("stale.mp4")
        var state = runtimeMediaState(url: runtimeURL)
        state.media.isPlaying = false
        state.media.currentTime = 42
        state.media.duration = 120
        state.media.generation = 9
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .mediaOwned)
        viewModel.avCoordinator.load(url: staleURL)
        viewModel.avCoordinator.isPlaying = true
        viewModel.avCoordinator.currentTime = 7
        viewModel.avCoordinator.duration = 5

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertEqual(viewModel.runtime.state.media.loadedURL, runtimeURL)
        XCTAssertFalse(viewModel.runtime.state.media.isPlaying)
        XCTAssertEqual(viewModel.runtime.state.media.currentTime, 42)
        XCTAssertEqual(viewModel.runtime.state.media.duration, 120)
        XCTAssertEqual(viewModel.runtime.state.media.generation, 9)
    }

    func testNonMediaOwnedSnapshotUsesAVCoordinatorMediaState() {
        let staleURL = mediaURL("facade.mp4")
        let viewModel = makeViewModel(runtimeState: runtimeMediaState(url: mediaURL("runtime.mp4")), bridgeMode: .audioOwned)
        viewModel.avCoordinator.load(url: staleURL)
        viewModel.avCoordinator.isPlaying = true
        viewModel.avCoordinator.currentTime = 7
        viewModel.avCoordinator.duration = 5

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertEqual(viewModel.runtime.state.media.loadedURL, staleURL)
        XCTAssertTrue(viewModel.runtime.state.media.isPlaying)
        XCTAssertEqual(viewModel.runtime.state.media.currentTime, 7)
        XCTAssertEqual(viewModel.runtime.state.media.duration, 5)
    }

    private func makeViewModel(
        runtimeState: LiveRuntimeState,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            initialState: runtimeState,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, runtime: runtime)
    }

    private func runtimeMediaState(url: URL) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.media.loadedURL = url
        state.media.isPlaying = false
        state.media.currentTime = 42
        state.media.duration = 120
        state.media.generation = 9
        return state
    }

    private func mediaURL(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(name)")
    }
}
