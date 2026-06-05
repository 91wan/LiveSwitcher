import AppKit
import SwiftUI
import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelProjectionOutputBehaviorTests: XCTestCase {
    func testHandleBroadcastToggleStillDispatchesRuntimeProjectionToggle() throws {
        let viewModel = try makeProjectionViewModel(isBroadcasting: false, hasExternalDisplay: true)

        viewModel.handleBroadcastToggle()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorToggledProjection" })
        XCTAssertTrue(viewModel.runtime.recordedEffects.contains(.startProjection))
    }

    func testHandleBroadcastToggleStillRefreshesExternalDisplayAvailabilityBeforeDispatch() throws {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }
        let viewModel = try makeProjectionViewModel(isBroadcasting: false, hasExternalDisplay: false)
        viewModel.externalScreenProvider = { screen }

        viewModel.handleBroadcastToggle()

        XCTAssertTrue(viewModel.runtime.state.projection.hasExternalDisplay)
        XCTAssertTrue(viewModel.runtime.state.projection.isBroadcasting)
    }

    func testProjectionStartStillUsesProjectionPortOutputPath() throws {
        let (viewModel, output) = try makeProjectionViewModelWithOutputSpy()

        viewModel.handleBroadcastToggle()

        XCTAssertEqual(output.showCount, 1)
        XCTAssertEqual(output.mountCount, 1)
    }

    func testProjectionStartFailureStillRecordsStartFailedNotDisplayLost() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.externalScreenProvider = { nil }
        viewModel.refreshExternalDisplayAvailability()

        viewModel.handleBroadcastToggle()

        XCTAssertEqual(viewModel.supportEvents.filter { $0.kind == .projectionStartFailed }.count, 1)
        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .projectionLost })
    }

    func testExternalDisplayLostStillDispatchesRuntimeAction() throws {
        let viewModel = try makeProjectionViewModel(isBroadcasting: true, hasExternalDisplay: true)

        viewModel.handleExternalDisplayLost()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "projectionExternalDisplayLost" })
        XCTAssertFalse(viewModel.isBroadcasting)
    }

    func testExternalDisplayLostStillRecordsSupportOnce() throws {
        let viewModel = try makeProjectionViewModel(isBroadcasting: true, hasExternalDisplay: true)

        viewModel.handleExternalDisplayLost()
        viewModel.handleExternalDisplayLost()

        XCTAssertEqual(viewModel.supportEvents.filter { $0.kind == .projectionLost }.count, 1)
        XCTAssertEqual(viewModel.supportEvents.filter { $0.kind == .projectionFailClosed }.count, 1)
    }

    func testProjectionSupportEventsAreNotDuplicated() throws {
        let source = try projectionSource()
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "recordProjectionSupportAfterRuntimeToggle"))

        XCTAssertLessThanOrEqual(body.components(separatedBy: ".projectionStarted").count - 1, 1)
        XCTAssertLessThanOrEqual(body.components(separatedBy: ".projectionStopped").count - 1, 1)
        XCTAssertLessThanOrEqual(body.components(separatedBy: ".projectionStartFailed").count - 1, 1)
    }

    func testProjectionOutputWindowStillMountsOutputViewOnce() throws {
        let (viewModel, output) = try makeProjectionViewModelWithOutputSpy()

        viewModel.handleBroadcastToggle()
        viewModel.handleBroadcastToggle()
        viewModel.handleBroadcastToggle()

        XCTAssertEqual(output.mountCount, 1)
        XCTAssertEqual(output.showCount, 2)
        XCTAssertEqual(output.hideCount, 1)
    }

    private func makeProjectionViewModel(
        isBroadcasting: Bool,
        hasExternalDisplay: Bool
    ) throws -> SwitcherViewModel {
        let screen = NSScreen.main ?? NSScreen.screens.first
        if hasExternalDisplay, screen == nil {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }
        var state = LiveRuntimeState()
        state.projection.isBroadcasting = isBroadcasting
        state.projection.hasExternalDisplay = hasExternalDisplay
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .projectionOwned)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        viewModel.isBroadcasting = isBroadcasting
        viewModel.externalScreenProvider = { hasExternalDisplay ? screen : nil }
        viewModel.refreshExternalDisplayAvailability()
        return viewModel
    }

    private func makeProjectionViewModelWithOutputSpy() throws -> (SwitcherViewModel, ProjectionOutputSpy) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let output = ProjectionOutputSpy()
        viewModel.outputWindowControllerFactory = { output }
        viewModel.externalScreenProvider = { screen }
        return (viewModel, output)
    }

    private func projectionSource() throws -> String {
        if let source = try optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProjectionOutput.swift") {
            return source
        }
        return try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }
}

private final class ProjectionOutputSpy: OutputWindowControlling {
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
