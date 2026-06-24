import CoreGraphics
import XCTest
@testable import LiveSwitcher

final class LowerThirdTypographyMetricsTests: XCTestCase {
    func testTypographyScalesAndClampsAcrossCanvasHeights() {
        let small = LowerThirdTypographyMetrics.metrics(forCanvasHeight: 720, canvasWidth: 1280)
        XCTAssertGreaterThanOrEqual(small.nameFontSize, 36)
        XCTAssertGreaterThanOrEqual(small.titleFontSize, 20)

        let hd = LowerThirdTypographyMetrics.metrics(forCanvasHeight: 1080, canvasWidth: 1920)
        XCTAssertGreaterThanOrEqual(hd.nameFontSize, 44)
        XCTAssertLessThanOrEqual(hd.nameFontSize, 48)
        XCTAssertGreaterThanOrEqual(hd.titleFontSize, 23)
        XCTAssertLessThanOrEqual(hd.titleFontSize, 26)
        XCTAssertEqual(hd.accentWidth, 6, accuracy: 0.001)
        XCTAssertEqual(hd.horizontalPadding, 24, accuracy: 0.001)
        XCTAssertEqual(hd.verticalPadding, 16, accuracy: 0.001)
        XCTAssertEqual(hd.maxWidth, min(820, 1920 * 0.62), accuracy: 0.001)

        let large = LowerThirdTypographyMetrics.metrics(forCanvasHeight: 2160, canvasWidth: 3840)
        XCTAssertLessThanOrEqual(large.nameFontSize, 54)
        XCTAssertLessThanOrEqual(large.titleFontSize, 30)
    }

    func testLongTextKeepsAStableSafeBoxAndReadableScaleFactor() {
        let metrics = LowerThirdTypographyMetrics.metrics(forCanvasHeight: 1080, canvasWidth: 1920)

        XCTAssertLessThanOrEqual(metrics.maxWidth, 820)
        XCTAssertGreaterThanOrEqual(metrics.minimumTextScaleFactor, 0.72)
        XCTAssertGreaterThan(metrics.nameFontSize, metrics.titleFontSize)
    }
}
