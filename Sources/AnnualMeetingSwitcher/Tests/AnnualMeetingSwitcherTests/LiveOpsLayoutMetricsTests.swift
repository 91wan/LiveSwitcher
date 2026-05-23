import XCTest
@testable import LiveSwitcher

final class LiveOpsLayoutMetricsTests: XCTestCase {
    func testLiveOpsHitTargetsStayOperatorSized() {
        XCTAssertGreaterThanOrEqual(LiveOpsLayoutMetrics.cardPadding, 10)
        XCTAssertGreaterThanOrEqual(LiveOpsLayoutMetrics.outputPrimaryButtonHeight, 42)
        XCTAssertGreaterThanOrEqual(LiveOpsLayoutMetrics.bgmTransportButtonSize, 32)
        XCTAssertGreaterThanOrEqual(LiveOpsLayoutMetrics.modeRowHeight, 34)
    }
}
