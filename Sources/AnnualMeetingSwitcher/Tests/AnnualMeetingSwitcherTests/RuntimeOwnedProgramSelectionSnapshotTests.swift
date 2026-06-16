import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeOwnedProgramSelectionSnapshotTests: XCTestCase {
    func testProgramSelectionOwnedAudioFacadeSnapshotUsesRuntimeCurrentProgramMediaSource() {
        let viewModel = makeProgramSelectionViewModel(runtimeCurrentIsMedia: true, staleFacadeCurrentIsMedia: false, bridgeMode: .programSelectionOwned)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isCurrentProgramMediaSource)
    }

    func testProgramSelectionOwnedAudioRoutingContextUsesRuntimeCurrentProgramMediaSource() {
        let viewModel = makeProgramSelectionViewModel(runtimeCurrentIsMedia: true, staleFacadeCurrentIsMedia: false, bridgeMode: .programSelectionOwned)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isCurrentProgramMediaSource)
    }

    func testProgramSelectionOwnedAudioRoutingContextDoesNotUseStaleFacadeCurrentProgramMediaSource() {
        let viewModel = makeProgramSelectionViewModel(runtimeCurrentIsMedia: false, staleFacadeCurrentIsMedia: true, bridgeMode: .programSelectionOwned)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertFalse(viewModel.runtime.state.audio.routingContext.isCurrentProgramMediaSource)
    }

    func testNonProgramSelectionOwnedAudioRoutingContextUsesFacadeCurrentProgramMediaSource() {
        let viewModel = makeProgramSelectionViewModel(runtimeCurrentIsMedia: false, staleFacadeCurrentIsMedia: true, bridgeMode: .programQueueOwned)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)

        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isCurrentProgramMediaSource)
    }

    func testProgramSelectionOwnedDispatchDoesNotOverwriteRoutingContextWithStaleFacadeCurrentProgram() {
        let viewModel = makeProgramSelectionViewModel(runtimeCurrentIsMedia: false, staleFacadeCurrentIsMedia: true, bridgeMode: .programSelectionOwned)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertFalse(viewModel.runtime.state.audio.routingContext.isCurrentProgramMediaSource)
    }

    private func makeProgramSelectionViewModel(
        runtimeCurrentIsMedia: Bool,
        staleFacadeCurrentIsMedia: Bool,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> SwitcherViewModel {
        let runtimeItem = runtimeCurrentIsMedia ? mediaItem("runtime") : nonMediaItem("runtime")
        var state = LiveRuntimeState()
        state.program.items = [runtimeItem]
        state.program.currentID = runtimeItem.id
        state.audio.routingContext.isCurrentProgramMediaSource = runtimeCurrentIsMedia
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, runtime: runtime)
        let facadeItem = staleFacadeCurrentIsMedia ? mediaItem("facade") : nonMediaItem("facade")
        viewModel.applyProgramQueueProjectionFromRuntime([facadeItem])
        viewModel.applyCurrentProgramProjectionFromRuntime(facadeItem, switchedAt: Date(timeIntervalSince1970: 1))
        return viewModel
    }

    private func mediaItem(_ title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "VIDEO", sourceURL: URL(fileURLWithPath: "/tmp/\(title).mp4"))
    }

    private func nonMediaItem(_ title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "KEYNOTE", sourceURL: URL(fileURLWithPath: "/tmp/\(title).key"))
    }
}
