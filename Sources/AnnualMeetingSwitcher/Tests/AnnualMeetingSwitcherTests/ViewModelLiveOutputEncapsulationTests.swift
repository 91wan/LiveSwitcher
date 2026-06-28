import AppKit
import SwiftUI
import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelLiveOutputEncapsulationTests: XCTestCase {
    func testProjectionOutputControllerIsMountedOnceAndReusedAcrossToggleCycles() throws {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let output = LiveOutputEncapsulationOutputSpy()
        viewModel.outputWindowControllerFactory = { output }
        viewModel.externalScreenProvider = { screen }

        viewModel.handleBroadcastToggle()
        viewModel.handleBroadcastToggle()
        viewModel.handleBroadcastToggle()

        XCTAssertEqual(output.mountCount, 1)
        XCTAssertEqual(output.showCount, 2)
        XCTAssertEqual(output.hideCount, 1)
        XCTAssertTrue(viewModel.currentOutputWindowControllerForProjection() === output)
    }

    func testExternalDisplayAvailabilityFeedsRuntimeSnapshotAndPreflightSnapshot() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .recordingOnly)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )

        viewModel.updateExternalDisplayAvailabilityForProjection(true)
        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        XCTAssertTrue(viewModel.isExternalDisplayAvailable)
        XCTAssertTrue(viewModel.runtime.state.projection.hasExternalDisplay)
        XCTAssertTrue(viewModel.livePreflightSnapshot.hasExternalDisplay)
    }

    func testOutputControllerUnavailableCallbackStillStopsBroadcastThroughRuntime() throws {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let output = LiveOutputEncapsulationOutputSpy()
        viewModel.outputWindowControllerFactory = { output }
        viewModel.externalScreenProvider = { screen }

        viewModel.handleBroadcastToggle()
        output.onExternalDisplayUnavailable?()

        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "projectionExternalDisplayLost" })
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionLost })
    }
}

private final class LiveOutputEncapsulationOutputSpy: OutputWindowControlling {
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
