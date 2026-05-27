import XCTest
@testable import LiveSwitcher

final class PanicButtonModelTests: XCTestCase {
    func testInactiveSetupPanicStillUsesDangerVisualRole() {
        let model = PanicButtonModel.make(isActive: false, consoleMode: .setup)

        XCTAssertEqual(model.visualRole, .danger)
        XCTAssertEqual(model.title, "紧急切黑")
        XCTAssertEqual(model.subtitle, "一键应急")
        XCTAssertFalse(model.help.contains("老板键"))
        XCTAssertGreaterThanOrEqual(model.height, ToolbarLayoutMetrics.actionHeight)
    }

    func testLiveModePanicUsesSharedChromeHeight() {
        let model = PanicButtonModel.make(isActive: false, consoleMode: .live)

        XCTAssertEqual(model.visualRole, .danger)
        XCTAssertEqual(model.height, ToolbarLayoutMetrics.actionHeight)
        XCTAssertEqual(model.minWidth, ToolbarLayoutMetrics.panicMinWidth)
    }

    func testActivePanicCopyStatesEmergencyBlackoutIsOn() {
        let model = PanicButtonModel.make(isActive: true, consoleMode: .setup)

        XCTAssertEqual(model.visualRole, .danger)
        XCTAssertEqual(model.systemImage, "eye.slash.fill")
        XCTAssertEqual(model.title, "紧急切黑: 开")
        XCTAssertEqual(model.subtitle, "副屏黑屏 · 音频静音")
        XCTAssertTrue(model.accessibilityHint.localizedStandardContains("副屏黑屏"))
    }
}
