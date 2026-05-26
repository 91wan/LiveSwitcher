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

        XCTAssertEqual(model.title, "需要外接屏")
        XCTAssertEqual(model.statusText, "警告")
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

        XCTAssertEqual(model.title, "开始投射")
        XCTAssertEqual(model.statusText, "待机")
        XCTAssertTrue(model.isEnabled)
    }

    func testProjectionButtonAllowsStopWhenBroadcastingAfterDisplayLoss() {
        let model = ProjectionButtonModel.make(
            isBroadcasting: true,
            hasExternalDisplay: false,
            safetyNotice: nil
        )

        XCTAssertEqual(model.title, "停止投射")
        XCTAssertEqual(model.statusText, "副屏丢失")
        XCTAssertEqual(model.statusKind, .fail)
        XCTAssertEqual(model.screenLabel, "副屏已断开")
        XCTAssertEqual(model.warningTitle, "副屏丢失")
        XCTAssertTrue(model.isEnabled)
    }

    func testProjectionButtonModelStatesCoverDisplayAndBroadcastingMatrix() {
        let displayLost = ProjectionButtonModel.make(isBroadcasting: true, hasExternalDisplay: false, safetyNotice: nil)
        let onAir = ProjectionButtonModel.make(isBroadcasting: true, hasExternalDisplay: true, safetyNotice: nil)
        let noDisplay = ProjectionButtonModel.make(isBroadcasting: false, hasExternalDisplay: false, safetyNotice: nil)
        let standby = ProjectionButtonModel.make(isBroadcasting: false, hasExternalDisplay: true, safetyNotice: nil)

        XCTAssertEqual(displayLost.statusText, "副屏丢失")
        XCTAssertEqual(displayLost.statusKind, .fail)
        XCTAssertEqual(onAir.statusText, "直播")
        XCTAssertEqual(onAir.statusKind, .live)
        XCTAssertEqual(noDisplay.statusText, "警告")
        XCTAssertEqual(noDisplay.statusKind, .warn)
        XCTAssertFalse(noDisplay.isEnabled)
        XCTAssertEqual(standby.statusText, "待机")
        XCTAssertEqual(standby.statusKind, .idle)
        XCTAssertTrue(standby.isEnabled)
    }
}
