import XCTest
@testable import LiveSwitcher

final class PanicButtonModelTests: XCTestCase {
    func testInactiveSetupPanicStillUsesDangerVisualRole() {
        let model = PanicButtonModel.make(isActive: false, consoleMode: .setup)

        XCTAssertEqual(model.visualRole, .danger)
        XCTAssertEqual(model.title, "老板键")
        XCTAssertEqual(model.subtitle, "紧急切黑")
        XCTAssertGreaterThanOrEqual(model.height, ToolbarLayoutMetrics.actionHeight)
    }

    func testLiveModePanicKeepsLargeEmergencyTarget() {
        let model = PanicButtonModel.make(isActive: false, consoleMode: .live)

        XCTAssertEqual(model.visualRole, .danger)
        XCTAssertGreaterThanOrEqual(model.height, 56)
        XCTAssertGreaterThan(model.minWidth, ToolbarLayoutMetrics.panicMinWidth)
    }

    func testActivePanicCopyStatesBlackoutIsOn() {
        let model = PanicButtonModel.make(isActive: true, consoleMode: .setup)

        XCTAssertEqual(model.visualRole, .danger)
        XCTAssertEqual(model.systemImage, "eye.slash.fill")
        XCTAssertEqual(model.title, "老板键: 开")
        XCTAssertEqual(model.subtitle, "切黑静音")
        XCTAssertTrue(model.accessibilityHint.localizedStandardContains("副屏已切黑"))
    }
}
