import XCTest
@testable import LiveSwitcher

final class ToolbarLayoutMetricsTests: XCTestCase {
    func testToolbarActionWidthsFitInsideMinimumRunDeskChrome() {
        XCTAssertGreaterThanOrEqual(ToolbarLayoutMetrics.panicMinWidth, 104)
        XCTAssertGreaterThanOrEqual(ToolbarLayoutMetrics.preflightMinWidth, 104)
        XCTAssertGreaterThanOrEqual(ToolbarLayoutMetrics.helpMinWidth, 76)
        XCTAssertEqual(
            ToolbarLayoutMetrics.totalMinWidth,
            ToolbarLayoutMetrics.panicMinWidth
                + ToolbarLayoutMetrics.preflightMinWidth
                + ToolbarLayoutMetrics.helpMinWidth
                + ToolbarLayoutMetrics.interItemSpacing * 2
        )
        XCTAssertLessThanOrEqual(ToolbarLayoutMetrics.totalMinWidth, ToolbarLayoutMetrics.availableWidthAtMinimumWindow)
    }
}
