import XCTest
@testable import LiveSwitcher

final class ToolbarLayoutMetricsTests: XCTestCase {
    func testToolbarActionWidthsFitInsideMinimumRunDeskChrome() {
        XCTAssertGreaterThanOrEqual(ToolbarLayoutMetrics.panicMinWidth, 104)
        XCTAssertGreaterThanOrEqual(ToolbarLayoutMetrics.panicToModeClusterSpacing, 28)
        XCTAssertGreaterThanOrEqual(ToolbarLayoutMetrics.modeButtonMinWidth, 112)
        XCTAssertEqual(
            ToolbarLayoutMetrics.modeButtonGroupMinWidth,
            ToolbarLayoutMetrics.modeButtonMinWidth * 2 + ToolbarLayoutMetrics.modeButtonSpacing
        )
        XCTAssertGreaterThanOrEqual(ToolbarLayoutMetrics.preflightMinWidth, 104)
        XCTAssertGreaterThanOrEqual(ToolbarLayoutMetrics.helpMinWidth, 76)
        XCTAssertEqual(
            ToolbarLayoutMetrics.totalMinWidth,
            ToolbarLayoutMetrics.modeButtonGroupMinWidth
                + ToolbarLayoutMetrics.preflightMinWidth
                + ToolbarLayoutMetrics.helpMinWidth
                + ToolbarLayoutMetrics.interItemSpacing * 2
        )
        XCTAssertLessThanOrEqual(ToolbarLayoutMetrics.totalMinWidth, ToolbarLayoutMetrics.availableWidthAtMinimumWindow)
    }

    func testPanicAndToolbarControlsShareChromeHeight() {
        XCTAssertEqual(PanicButtonModel.make(isActive: false, consoleMode: .live).height, ToolbarLayoutMetrics.actionHeight)
        XCTAssertEqual(PanicButtonModel.make(isActive: false, consoleMode: .setup).height, ToolbarLayoutMetrics.actionHeight)
    }
}
