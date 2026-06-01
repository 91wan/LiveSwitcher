import AppKit
import SwiftUI
import XCTest
@testable import LiveSwitcher

@MainActor
final class LiveRuntimeProjectionBridgeTests: XCTestCase {
    private final class OutputWindowControllerSpy: OutputWindowControlling {
        var onExternalDisplayUnavailable: (() -> Void)?
        private(set) var mountCount = 0
        private(set) var showCount = 0
        private(set) var hideCount = 0

        func mountAnyView(rootView: AnyView) {
            mountCount += 1
        }

        func show(on screen: NSScreen?) {
            showCount += 1
        }

        func hide() {
            hideCount += 1
        }
    }

    func testProjectionStartWithDisplayProducesStartAndShowEffects() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorToggledProjection,
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertTrue(mutation.state.projection.isBroadcasting)
        XCTAssertNil(mutation.state.projection.safetyNotice)
        XCTAssertTrue(mutation.effects.contains(.startProjection))
        XCTAssertTrue(mutation.effects.contains(.showOutputWindow))
        XCTAssertTrue(mutation.state.support.events.contains { $0.kind == .projectionStarted })
    }

    func testProjectionStartWithoutDisplayFailsClosed() {
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorToggledProjection,
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertFalse(mutation.state.projection.isBroadcasting)
        XCTAssertEqual(mutation.state.projection.safetyNotice, "No external display")
        XCTAssertFalse(mutation.effects.contains(.startProjection))
        XCTAssertFalse(mutation.effects.contains(.showOutputWindow))
        XCTAssertTrue(mutation.state.support.events.contains { $0.kind == .projectionStartFailed })
    }

    func testProjectionDisplayLossStopsBroadcastingOnce() {
        var state = LiveRuntimeState()
        state.projection.isBroadcasting = true
        state.projection.hasExternalDisplay = true

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .projectionExternalDisplayLost,
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100))
        )
        let repeated = LiveRuntimeReducer.reduce(
            state: mutation.state,
            action: .projectionExternalDisplayLost,
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 101))
        )

        XCTAssertFalse(mutation.state.projection.isBroadcasting)
        XCTAssertFalse(mutation.state.projection.hasExternalDisplay)
        XCTAssertNotNil(mutation.state.projection.lastDisplayLostAt)
        XCTAssertTrue(mutation.effects.contains(.stopProjection))
        XCTAssertEqual(mutation.state.support.events.filter { $0.kind == .projectionLost }.count, 1)
        XCTAssertEqual(repeated.state.support.events.filter { $0.kind == .projectionLost }.count, 1)
        XCTAssertTrue(repeated.effects.isEmpty)
    }

    func testProjectionDisplayLossWhileStandbyUpdatesAvailabilityWithoutStopEffect() {
        var state = LiveRuntimeState()
        state.projection.isBroadcasting = false
        state.projection.hasExternalDisplay = true

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .projectionExternalDisplayLost,
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertFalse(mutation.state.projection.isBroadcasting)
        XCTAssertFalse(mutation.state.projection.hasExternalDisplay)
        XCTAssertNil(mutation.state.projection.lastDisplayLostAt)
        XCTAssertFalse(mutation.effects.contains(.stopProjection))
        XCTAssertFalse(mutation.state.support.events.contains { $0.kind == .projectionLost })
    }

    func testProjectionDisplayAvailableCallbackClearsLostState() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = false
        state.projection.safetyNotice = "No external display"
        state.projection.lastDisplayLostAt = Date(timeIntervalSince1970: 50)

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .projectionExternalDisplayAvailable,
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertTrue(mutation.state.projection.hasExternalDisplay)
        XCTAssertNil(mutation.state.projection.safetyNotice)
        XCTAssertNil(mutation.state.projection.lastDisplayLostAt)
    }

    func testProjectionDisplayUnavailableCallbackOnlyUpdatesAvailabilityCache() {
        var state = LiveRuntimeState()
        state.projection.isBroadcasting = true
        state.projection.hasExternalDisplay = true

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .projectionExternalDisplayUnavailable,
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertTrue(mutation.state.projection.isBroadcasting)
        XCTAssertFalse(mutation.state.projection.hasExternalDisplay)
        XCTAssertFalse(mutation.effects.contains(.stopProjection))
        XCTAssertFalse(mutation.state.support.events.contains { $0.kind == .projectionLost })
    }

    func testViewModelExternalDisplayRefreshDispatchesAvailabilityCallbacks() throws {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }
        let viewModel = makeViewModelWithoutDisplay()
        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        viewModel.externalScreenProvider = { screen }

        XCTAssertTrue(viewModel.isExternalDisplayAvailable)
        XCTAssertEqual(viewModel.runtime.actionLog.last?.actionName, "projectionExternalDisplayAvailable")
        XCTAssertTrue(viewModel.runtime.state.projection.hasExternalDisplay)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)
        viewModel.externalScreenProvider = { nil }

        XCTAssertFalse(viewModel.isExternalDisplayAvailable)
        XCTAssertEqual(viewModel.runtime.actionLog.last?.actionName, "projectionExternalDisplayUnavailable")
        XCTAssertFalse(viewModel.runtime.state.projection.hasExternalDisplay)
    }

    func testViewModelBroadcastToggleDispatchesProjectionRuntimeAction() throws {
        let viewModel = try makeViewModelWithDisplay()
        let outputSpy = OutputWindowControllerSpy()
        viewModel.outputWindowControllerFactory = { outputSpy }

        viewModel.handleBroadcastToggle()

        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertTrue(viewModel.runtime.state.projection.isBroadcasting)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorToggledProjection" })
    }

    func testViewModelSafeBroadcastStopDispatchesProjectionRuntimeAction() throws {
        let viewModel = try makeViewModelWithDisplay()
        let outputSpy = OutputWindowControllerSpy()
        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.handleBroadcastToggle()

        viewModel.handleSafeBroadcastToggle()

        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.hideCount, 1)
        XCTAssertTrue(viewModel.runtime.actionLog.filter { $0.actionName == "operatorToggledProjection" }.count >= 2)
    }

    func testViewModelDisplayLostDispatchesProjectionRuntimeCallback() throws {
        let viewModel = try makeViewModelWithDisplay()
        let outputSpy = OutputWindowControllerSpy()
        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.handleBroadcastToggle()

        viewModel.handleExternalDisplayLost()

        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "projectionExternalDisplayLost" })
        XCTAssertEqual(viewModel.runtime.actionLog.last?.actionName, "supportEventRecorded")
        XCTAssertFalse(viewModel.runtime.state.projection.isBroadcasting)
        XCTAssertEqual(viewModel.broadcastSafetyNotice, "副屏已断开，投射已停止")
    }

    private func makeViewModelWithDisplay() throws -> SwitcherViewModel {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }
        let suiteName = "LiveRuntimeProjectionBridgeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
        viewModel.externalScreenProvider = { screen }
        return viewModel
    }

    private func makeViewModelWithoutDisplay() -> SwitcherViewModel {
        let suiteName = "LiveRuntimeProjectionBridgeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
        viewModel.externalScreenProvider = { nil }
        return viewModel
    }
}
