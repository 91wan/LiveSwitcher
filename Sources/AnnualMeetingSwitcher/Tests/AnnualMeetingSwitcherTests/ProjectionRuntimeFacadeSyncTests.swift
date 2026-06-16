import AppKit
import XCTest
@testable import LiveSwitcher

@MainActor
final class ProjectionRuntimeFacadeSyncTests: XCTestCase {
    func testProjectionFacadeSyncProjectsHasExternalDisplayTrue() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .projectionOwned)
        viewModel.updateExternalDisplayAvailabilityForProjection(false)

        viewModel.syncProjectionFacadeFromRuntime()

        XCTAssertTrue(viewModel.isExternalDisplayAvailable)
    }

    func testProjectionFacadeSyncProjectsHasExternalDisplayFalse() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = false
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .projectionOwned)
        viewModel.updateExternalDisplayAvailabilityForProjection(true)

        viewModel.syncProjectionFacadeFromRuntime()

        XCTAssertFalse(viewModel.isExternalDisplayAvailable)
    }

    func testProjectionFacadeSyncProjectsBroadcasting() {
        var state = LiveRuntimeState()
        state.projection.isBroadcasting = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .projectionOwned)
        viewModel.isBroadcasting = false

        viewModel.syncProjectionFacadeFromRuntime()

        XCTAssertTrue(viewModel.isBroadcasting)
    }

    func testProjectionFacadeSyncProjectsSafetyNotice() {
        var state = LiveRuntimeState()
        state.projection.safetyNotice = "runtime notice"
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .projectionOwned)
        viewModel.broadcastSafetyNotice = nil

        viewModel.syncProjectionFacadeFromRuntime()

        XCTAssertEqual(viewModel.broadcastSafetyNotice, "runtime notice")
    }

    func testProjectionFacadeSyncClearsSafetyNotice() {
        let viewModel = makeViewModel(runtimeState: LiveRuntimeState(), bridgeMode: .projectionOwned)
        viewModel.broadcastSafetyNotice = "stale notice"

        viewModel.syncProjectionFacadeFromRuntime()

        XCTAssertNil(viewModel.broadcastSafetyNotice)
    }

    func testProjectionFacadeSyncNoopsBeforeProjectionOwnership() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true
        state.projection.isBroadcasting = true
        state.projection.safetyNotice = "runtime notice"
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .bgmOwned)
        viewModel.updateExternalDisplayAvailabilityForProjection(false)
        viewModel.isBroadcasting = false
        viewModel.broadcastSafetyNotice = "facade notice"

        viewModel.syncProjectionFacadeFromRuntime()

        XCTAssertFalse(viewModel.isExternalDisplayAvailable)
        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertEqual(viewModel.broadcastSafetyNotice, "facade notice")
    }

    func testProjectionFacadeSyncUsesExternalDisplayAvailabilityHelper() throws {
        let body = try projectionFacadeSyncBody()

        XCTAssertTrue(
            body.contains("updateExternalDisplayAvailabilityForProjection(runtime.state.projection.hasExternalDisplay)")
        )
    }

    func testProjectionFacadeSyncDoesNotSetExternalDisplayAvailabilityDirectly() throws {
        let body = try projectionFacadeSyncBody()

        XCTAssertFalse(body.contains("isExternalDisplayAvailable ="))
    }

    func testProjectionExternalDisplayAvailableSyncsFacadeAvailabilityTrue() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = false
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .projectionOwned)
        viewModel.updateExternalDisplayAvailabilityForProjection(false)

        viewModel.dispatchRuntimeFacadeAction(.projectionExternalDisplayAvailable)

        XCTAssertTrue(viewModel.runtime.state.projection.hasExternalDisplay)
        XCTAssertTrue(viewModel.isExternalDisplayAvailable)
    }

    func testProjectionExternalDisplayUnavailableSyncsFacadeAvailabilityFalse() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .projectionOwned)
        viewModel.updateExternalDisplayAvailabilityForProjection(true)

        viewModel.dispatchRuntimeFacadeAction(.projectionExternalDisplayUnavailable)

        XCTAssertFalse(viewModel.runtime.state.projection.hasExternalDisplay)
        XCTAssertFalse(viewModel.isExternalDisplayAvailable)
    }

    func testProjectionExternalDisplayLostSyncsFacadeAvailabilityFalse() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true
        state.projection.isBroadcasting = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .projectionOwned)
        viewModel.updateExternalDisplayAvailabilityForProjection(true)

        viewModel.dispatchRuntimeFacadeAction(.projectionExternalDisplayLost)

        XCTAssertFalse(viewModel.runtime.state.projection.hasExternalDisplay)
        XCTAssertFalse(viewModel.isExternalDisplayAvailable)
    }

    func testProjectionStartFailedSyncsFacadeAvailabilityFalse() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .projectionOwned)
        viewModel.updateExternalDisplayAvailabilityForProjection(true)

        viewModel.dispatchRuntimeFacadeAction(.projectionStartFailed(reason: .noTargetScreen))

        XCTAssertFalse(viewModel.runtime.state.projection.hasExternalDisplay)
        XCTAssertFalse(viewModel.isExternalDisplayAvailable)
    }

    func testProjectionToggleStartSyncsFacadeAvailabilityTrue() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .projectionOwned)
        viewModel.updateExternalDisplayAvailabilityForProjection(false)

        viewModel.dispatchRuntimeFacadeAction(.operatorToggledProjection)

        XCTAssertTrue(viewModel.runtime.state.projection.hasExternalDisplay)
        XCTAssertTrue(viewModel.isExternalDisplayAvailable)
        XCTAssertTrue(viewModel.isBroadcasting)
    }

    func testProjectionToggleFailClosedSyncsFacadeAvailabilityFalse() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = false
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .projectionOwned)
        viewModel.updateExternalDisplayAvailabilityForProjection(true)

        viewModel.dispatchRuntimeFacadeAction(.operatorToggledProjection)

        XCTAssertFalse(viewModel.runtime.state.projection.hasExternalDisplay)
        XCTAssertFalse(viewModel.isExternalDisplayAvailable)
        XCTAssertFalse(viewModel.isBroadcasting)
    }

    func testProjectionCallbacksStillSyncProjectionFacade() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true
        state.projection.isBroadcasting = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .projectionOwned)
        viewModel.updateExternalDisplayAvailabilityForProjection(true)

        viewModel.dispatchRuntimeFacadeAction(.projectionExternalDisplayLost)

        XCTAssertFalse(viewModel.isExternalDisplayAvailable)
        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertEqual(viewModel.broadcastSafetyNotice, "副屏已断开，投射已停止")
    }

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

    func testProjectionStartFailureSyncsViewModelSafetyNoticeFromRuntime() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = false
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .projectionOwned)
        viewModel.externalScreenProvider = { nil }

        viewModel.handleBroadcastToggle()

        XCTAssertEqual(viewModel.runtime.state.projection.safetyNotice, "未检测到外接屏幕，未开始投射")
        XCTAssertEqual(viewModel.broadcastSafetyNotice, "未检测到外接屏幕，未开始投射")
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

    private func projectionFacadeSyncBody() throws -> String {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeFacadeSync.swift"
        )
        return try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "syncProjectionFacadeFromRuntime"))
    }
}
