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
        XCTAssertEqual(model.statusText, "ON AIR")
        XCTAssertTrue(model.isEnabled)
    }
}
