import XCTest
@testable import LiveSwitcher

final class OutputOverlayLayoutTests: XCTestCase {
    func testBusinessOverlaysUseIndependentLayoutPlanFramesForAllVisibilityCombinations() {
        let combinations: [(Bool, Bool, Bool)] = [
            (false, false, false),
            (true, false, false),
            (false, true, false),
            (false, false, true),
            (true, true, false),
            (true, false, true),
            (false, true, true),
            (true, true, true),
        ]

        for (ticker, countdown, lowerThird) in combinations {
            let plan = OutputOverlayLayoutPlan.make(
                canvasSize: CGSize(width: 1920, height: 1080),
                isTickerActive: ticker,
                isCountdownActive: countdown,
                isLowerThirdVisible: lowerThird,
                isLogoReady: false,
                logoPosition: .topRight
            )

            XCTAssertEqual(plan.tickerFrame != nil, ticker)
            XCTAssertEqual(plan.countdownFrame != nil, countdown)
            XCTAssertEqual(plan.lowerThirdFrame != nil, lowerThird)
        }
    }

    func testOutputOverlayLayerZOrderMatchesHardwareRehearsalContract() {
        XCTAssertEqual(OutputLayerZIndex.ticker, 2)
        XCTAssertEqual(OutputLayerZIndex.countdown, 3)
        XCTAssertEqual(OutputLayerZIndex.lowerThird, 5)
        XCTAssertEqual(OutputLayerZIndex.cornerLogo, 6)
        XCTAssertEqual(OutputLayerZIndex.fadeToBlack, 8)
        XCTAssertEqual(OutputLayerZIndex.panic, 10)

        XCTAssertLessThan(OutputLayerZIndex.ticker, OutputLayerZIndex.countdown)
        XCTAssertLessThan(OutputLayerZIndex.countdown, OutputLayerZIndex.lowerThird)
        XCTAssertLessThan(OutputLayerZIndex.lowerThird, OutputLayerZIndex.cornerLogo)
    }

    func testOutputOverlayLayerUsesAbsoluteZStackPlacements() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Views/ActiveProgramOverlayLayer.swift")

        XCTAssertTrue(source.contains("ZStack {"))
        XCTAssertTrue(source.contains("OutputOverlayLayoutPlan.make"))
        XCTAssertTrue(source.contains("plan.tickerFrame"))
        XCTAssertTrue(source.contains("plan.countdownFrame"))
        XCTAssertTrue(source.contains("plan.lowerThirdFrame"))
        XCTAssertTrue(source.contains(".zIndex(OutputLayerZIndex.ticker)"))
        XCTAssertTrue(source.contains(".zIndex(OutputLayerZIndex.countdown)"))
        XCTAssertTrue(source.contains(".zIndex(OutputLayerZIndex.lowerThird)"))
    }

    func testTickerRendersFullWidthTopBarInsteadOfFloatingCard() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Views/OutputOverlays/TickerOverlay.swift")

        XCTAssertEqual(OutputOverlayLayoutMetrics.tickerCornerRadius, 0)
        XCTAssertTrue(source.contains("Rectangle()"))
        XCTAssertTrue(source.contains("OutputOverlayLayoutMetrics.tickerBackgroundOpacity"))
        XCTAssertFalse(source.contains(".padding(.horizontal, OutputOverlayLayoutMetrics.tickerHorizontalPadding)"))
        XCTAssertFalse(source.contains(".padding(.top, OutputOverlayLayoutMetrics.tickerTopPadding)"))
        XCTAssertFalse(source.contains("Color.black.opacity(0.80)\n\n                    // A 轨道"))
        XCTAssertFalse(source.contains("Spacer()  // 把字幕条推到顶部"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
