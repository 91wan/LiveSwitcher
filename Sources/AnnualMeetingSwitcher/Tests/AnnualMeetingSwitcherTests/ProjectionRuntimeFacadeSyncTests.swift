import AppKit
import XCTest
@testable import LiveSwitcher

@MainActor
final class ProjectionRuntimeFacadeSyncTests: XCTestCase {
    func testProjectionOwnedFacadeSyncPreservesRuntimeBroadcasting() {
        var state = LiveRuntimeState()
        state.projection.isBroadcasting = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .projectionOwned)
        viewModel.isBroadcasting = false

        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        XCTAssertTrue(viewModel.runtime.state.projection.isBroadcasting)
    }

    func testProjectionOwnedFacadeSyncPreservesRuntimeSafetyNotice() {
        var state = LiveRuntimeState()
        state.projection.safetyNotice = "副屏已断开，投射已停止"
        state.projection.lastDisplayLostAt = Date(timeIntervalSince1970: 100)
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .projectionOwned)
        viewModel.broadcastSafetyNotice = nil

        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        XCTAssertEqual(viewModel.runtime.state.projection.safetyNotice, "副屏已断开，投射已停止")
        XCTAssertEqual(viewModel.runtime.state.projection.lastDisplayLostAt, Date(timeIntervalSince1970: 100))
    }

    func testProjectionOwnedFacadeSyncUpdatesExternalDisplayAvailability() throws {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = false
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .projectionOwned)
        viewModel.externalScreenProvider = { screen }
        viewModel.refreshExternalDisplayAvailability()

        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        XCTAssertTrue(viewModel.runtime.state.projection.hasExternalDisplay)
    }

    func testNonProjectionOwnedFacadeSyncMirrorsViewModelBroadcasting() {
        let viewModel = makeViewModel(runtimeState: LiveRuntimeState(), bridgeMode: .bgmOwned)
        viewModel.isBroadcasting = true
        viewModel.broadcastSafetyNotice = "notice"

        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        XCTAssertTrue(viewModel.runtime.state.projection.isBroadcasting)
        XCTAssertEqual(viewModel.runtime.state.projection.safetyNotice, "notice")
    }

    func testOperatorProjectionToggleSyncsViewModelBroadcastingFromRuntime() throws {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .projectionOwned)
        viewModel.externalScreenProvider = { screen }
        viewModel.refreshExternalDisplayAvailability()

        viewModel.handleBroadcastToggle()

        XCTAssertTrue(viewModel.runtime.state.projection.isBroadcasting)
        XCTAssertTrue(viewModel.isBroadcasting)
    }

    func testProjectionLostSyncsViewModelSafetyNoticeFromRuntime() {
        var state = LiveRuntimeState()
        state.projection.isBroadcasting = true
        state.projection.hasExternalDisplay = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .projectionOwned)

        viewModel.handleExternalDisplayLost()

        XCTAssertEqual(viewModel.runtime.state.projection.safetyNotice, "副屏已断开，投射已停止")
        XCTAssertEqual(viewModel.broadcastSafetyNotice, "副屏已断开，投射已停止")
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
