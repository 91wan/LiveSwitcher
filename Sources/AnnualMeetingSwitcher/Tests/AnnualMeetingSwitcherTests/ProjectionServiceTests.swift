import AppKit
import XCTest
@testable import LiveSwitcher

final class ProjectionServiceTests: XCTestCase {
    func testNoExternalDisplayIsNotReady() {
        let service = ProjectionService(externalScreenProvider: { nil })

        XCTAssertFalse(service.hasExternalDisplay)
        XCTAssertNil(service.targetScreen())
    }

    func testExternalDisplayProviderPassesThroughTargetScreen() throws {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }

        let service = ProjectionService(externalScreenProvider: { screen })

        XCTAssertTrue(service.hasExternalDisplay)
        XCTAssertTrue(service.targetScreen() === screen)
    }

    @MainActor
    func testProjectionButtonModelUsesInjectedProviderForMissingDisplay() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.externalScreenProvider = { nil }

        let model = ProjectionButtonModel.make(
            isBroadcasting: viewModel.isBroadcasting,
            hasExternalDisplay: viewModel.hasExternalDisplay,
            safetyNotice: nil
        )

        XCTAssertEqual(model.title, "External Display Required")
        XCTAssertEqual(model.statusText, "WARN")
        XCTAssertFalse(model.isEnabled)
    }

    @MainActor
    func testProjectionButtonModelUsesInjectedProviderForAvailableDisplay() throws {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.externalScreenProvider = { screen }

        let model = ProjectionButtonModel.make(
            isBroadcasting: viewModel.isBroadcasting,
            hasExternalDisplay: viewModel.hasExternalDisplay,
            safetyNotice: nil
        )

        XCTAssertEqual(model.title, "Start Projection")
        XCTAssertEqual(model.statusText, "STANDBY")
        XCTAssertTrue(model.isEnabled)
    }

    func testProjectionButtonAllowsStopWhenBroadcastingAfterDisplayLoss() {
        let model = ProjectionButtonModel.make(
            isBroadcasting: true,
            hasExternalDisplay: false,
            safetyNotice: nil
        )

        XCTAssertEqual(model.title, "Stop Projection")
        XCTAssertEqual(model.statusText, "DISPLAY LOST")
        XCTAssertEqual(model.statusKind, .fail)
        XCTAssertEqual(model.screenLabel, "副屏已断开")
        XCTAssertEqual(model.warningTitle, "Display Lost")
        XCTAssertTrue(model.isEnabled)
    }

    func testProjectionButtonModelStatesCoverDisplayAndBroadcastingMatrix() {
        let displayLost = ProjectionButtonModel.make(isBroadcasting: true, hasExternalDisplay: false, safetyNotice: nil)
        let onAir = ProjectionButtonModel.make(isBroadcasting: true, hasExternalDisplay: true, safetyNotice: nil)
        let noDisplay = ProjectionButtonModel.make(isBroadcasting: false, hasExternalDisplay: false, safetyNotice: nil)
        let standby = ProjectionButtonModel.make(isBroadcasting: false, hasExternalDisplay: true, safetyNotice: nil)

        XCTAssertEqual(displayLost.statusText, "DISPLAY LOST")
        XCTAssertEqual(displayLost.statusKind, .fail)
        XCTAssertEqual(onAir.statusText, "ON AIR")
        XCTAssertEqual(onAir.statusKind, .live)
        XCTAssertEqual(noDisplay.statusText, "WARN")
        XCTAssertEqual(noDisplay.statusKind, .warn)
        XCTAssertFalse(noDisplay.isEnabled)
        XCTAssertEqual(standby.statusText, "STANDBY")
        XCTAssertEqual(standby.statusKind, .idle)
        XCTAssertTrue(standby.isEnabled)
    }
}
