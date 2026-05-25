import XCTest
@testable import LiveSwitcher

final class PanicButtonModelTests: XCTestCase {
    func testInactiveSetupPanicStillUsesDangerVisualRole() {
        let model = PanicButtonModel.make(isActive: false, consoleMode: .setup)

        XCTAssertEqual(model.visualRole, .danger)
        XCTAssertEqual(model.title, "Blackout")
        XCTAssertEqual(model.subtitle, "Stage black")
        XCTAssertFalse(model.help.contains("老板键"))
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
        XCTAssertEqual(model.title, "Blackout: ON")
        XCTAssertEqual(model.subtitle, "Output muted")
        XCTAssertTrue(model.accessibilityHint.localizedStandardContains("Output is black"))
    }
}
