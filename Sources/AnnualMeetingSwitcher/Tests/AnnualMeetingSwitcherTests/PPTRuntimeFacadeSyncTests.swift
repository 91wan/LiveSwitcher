import XCTest
@testable import LiveSwitcher

@MainActor
final class PPTRuntimeFacadeSyncTests: XCTestCase {
    func testPPTOwnedFacadeSyncPreservesRuntimeRequested() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .pptOwned)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        XCTAssertTrue(viewModel.runtime.state.ppt.isRequested)
    }

    func testPPTOwnedFacadeSyncPreservesRuntimeActive() {
        var state = LiveRuntimeState()
        state.ppt.isEventTapActive = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .pptOwned)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        XCTAssertTrue(viewModel.runtime.state.ppt.isEventTapActive)
    }

    func testPPTOwnedFacadeSyncPreservesRuntimeFailureReason() {
        var state = LiveRuntimeState()
        state.ppt.lastFailureReason = "accessibilityPermission"
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .pptOwned)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        XCTAssertEqual(viewModel.runtime.state.ppt.lastFailureReason, "accessibilityPermission")
    }

    func testNonPPTOwnedFacadeSyncMirrorsViewModelState() {
        let viewModel = makeViewModel(runtimeState: LiveRuntimeState(), bridgeMode: .projectionOwned)
        viewModel.isPageInterceptEnabled = true

        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        XCTAssertTrue(viewModel.runtime.state.ppt.isRequested)
    }

    func testPPTEventTapStartedSyncsIsPageInterceptEnabledTrue() {
        let viewModel = makeViewModel(runtimeState: LiveRuntimeState(), bridgeMode: .pptOwned)

        viewModel.dispatchRuntimeFacadeAction(.pptEventTapStarted)

        XCTAssertTrue(viewModel.isPageInterceptEnabled)
    }

    func testPPTEventTapFailedSyncsIsPageInterceptEnabledFalse() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .pptOwned)

        viewModel.dispatchRuntimeFacadeAction(.pptEventTapFailed(reason: "accessibilityPermission"))

        XCTAssertFalse(viewModel.isPageInterceptEnabled)
    }

    func testPPTEventTapStoppedSyncsIsPageInterceptEnabledFalse() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        state.ppt.isEventTapActive = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .pptOwned)

        viewModel.dispatchRuntimeFacadeAction(.pptEventTapStopped(reason: .operatorDisabled))

        XCTAssertFalse(viewModel.isPageInterceptEnabled)
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
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
    }
}
