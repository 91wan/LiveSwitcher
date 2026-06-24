import CoreGraphics
import XCTest
@testable import LiveSwitcher

final class OutputOverlayGeometryContractTests: XCTestCase {
    func testTickerFrameIsFullWidthAtTopAcrossCanvasSizes() {
        for size in [CGSize(width: 1280, height: 720), CGSize(width: 1920, height: 1080), CGSize(width: 3840, height: 2160)] {
            let plan = OutputOverlayLayoutPlan.make(
                canvasSize: size,
                isTickerActive: true,
                isCountdownActive: false,
                isLowerThirdVisible: false,
                isLogoReady: false,
                logoPosition: .topRight
            )

            let tickerFrame = tryUnwrap(plan.tickerFrame)
            XCTAssertEqual(tickerFrame.minX, 0, accuracy: 0.001)
            XCTAssertEqual(tickerFrame.minY, 0, accuracy: 0.001)
            XCTAssertEqual(tickerFrame.width, size.width, accuracy: 0.001)
            XCTAssertGreaterThanOrEqual(tickerFrame.height, 64)
            XCTAssertLessThanOrEqual(tickerFrame.height, 72)
        }
    }

    func testOverlayCombinationsKeepCountdownCenteredAndLowerThirdAnchored() {
        let canvas = CGSize(width: 1920, height: 1080)
        for ticker in [false, true] {
            for countdown in [false, true] {
                for lowerThird in [false, true] {
                    let plan = OutputOverlayLayoutPlan.make(
                        canvasSize: canvas,
                        isTickerActive: ticker,
                        isCountdownActive: countdown,
                        isLowerThirdVisible: lowerThird,
                        isLogoReady: false,
                        logoPosition: .topRight
                    )

                    if countdown {
                        let countdownFrame = tryUnwrap(plan.countdownFrame)
                        XCTAssertEqual(countdownFrame.midX, canvas.width / 2, accuracy: 0.001)
                        XCTAssertEqual(countdownFrame.midY, canvas.height / 2, accuracy: 0.001)
                    } else {
                        XCTAssertNil(plan.countdownFrame)
                    }

                    if lowerThird {
                        let lowerThirdFrame = tryUnwrap(plan.lowerThirdFrame)
                        XCTAssertEqual(lowerThirdFrame.minX, OutputOverlayLayoutMetrics.lowerThirdOuterMargin, accuracy: 0.001)
                        XCTAssertEqual(lowerThirdFrame.maxY, canvas.height - OutputOverlayLayoutMetrics.lowerThirdBottomMargin, accuracy: 0.001)
                    } else {
                        XCTAssertNil(plan.lowerThirdFrame)
                    }
                }
            }
        }
    }

    func testLowerThirdStaysAboveBottomSafeArea() {
        let canvas = CGSize(width: 1920, height: 1080)
        let plan = OutputOverlayLayoutPlan.make(
            canvasSize: canvas,
            isTickerActive: false,
            isCountdownActive: false,
            isLowerThirdVisible: true,
            isLogoReady: false,
            logoPosition: .topRight
        )

        let lowerThirdFrame = tryUnwrap(plan.lowerThirdFrame)
        XCTAssertGreaterThanOrEqual(canvas.height - lowerThirdFrame.maxY, 96)
    }

    func testLogoUsesLowerThirdAlignedMarginsAndLargerDisplaySize() {
        let canvas = CGSize(width: 1920, height: 1080)
        let bottomRightPlan = OutputOverlayLayoutPlan.make(
            canvasSize: canvas,
            isTickerActive: false,
            isCountdownActive: false,
            isLowerThirdVisible: false,
            isLogoReady: true,
            logoPosition: .bottomRight
        )
        let bottomRightLogoFrame = tryUnwrap(bottomRightPlan.logoFrame)
        XCTAssertEqual(canvas.width - bottomRightLogoFrame.maxX, OutputOverlayLayoutMetrics.lowerThirdOuterMargin, accuracy: 0.001)
        XCTAssertEqual(canvas.height - bottomRightLogoFrame.maxY, OutputOverlayLayoutMetrics.lowerThirdBottomMargin, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(bottomRightLogoFrame.width, 320)
        XCTAssertGreaterThanOrEqual(bottomRightLogoFrame.height, 96)

        let bottomLeftPlan = OutputOverlayLayoutPlan.make(
            canvasSize: canvas,
            isTickerActive: false,
            isCountdownActive: false,
            isLowerThirdVisible: true,
            isLogoReady: true,
            logoPosition: .bottomLeft
        )
        let lowerThirdFrame = tryUnwrap(bottomLeftPlan.lowerThirdFrame)
        let bottomLeftLogoFrame = tryUnwrap(bottomLeftPlan.logoFrame)
        XCTAssertEqual(bottomLeftLogoFrame.minX, lowerThirdFrame.minX, accuracy: 0.001)
        XCTAssertGreaterThan(canvas.height - bottomLeftLogoFrame.maxY, OutputOverlayLayoutMetrics.lowerThirdBottomMargin)
        XCTAssertGreaterThanOrEqual(lowerThirdFrame.minY - bottomLeftLogoFrame.maxY, OutputOverlayLayoutMetrics.minimumLayerGap)
    }

    func testLogoAvoidsTickerAndLowerThirdWithoutShrinkingTicker() {
        let canvas = CGSize(width: 1920, height: 1080)
        let topPlan = OutputOverlayLayoutPlan.make(
            canvasSize: canvas,
            isTickerActive: true,
            isCountdownActive: false,
            isLowerThirdVisible: false,
            isLogoReady: true,
            logoPosition: .topRight
        )
        let tickerFrame = tryUnwrap(topPlan.tickerFrame)
        let topLogoFrame = tryUnwrap(topPlan.logoFrame)
        XCTAssertEqual(tickerFrame.width, canvas.width, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(topLogoFrame.minY - tickerFrame.maxY, OutputOverlayLayoutMetrics.minimumLayerGap)
        XCTAssertFalse(topLogoFrame.intersects(tickerFrame))

        let bottomPlan = OutputOverlayLayoutPlan.make(
            canvasSize: canvas,
            isTickerActive: false,
            isCountdownActive: false,
            isLowerThirdVisible: true,
            isLogoReady: true,
            logoPosition: .bottomLeft
        )
        let lowerThirdFrame = tryUnwrap(bottomPlan.lowerThirdFrame)
        let bottomLogoFrame = tryUnwrap(bottomPlan.logoFrame)
        XCTAssertGreaterThanOrEqual(lowerThirdFrame.minY - bottomLogoFrame.maxY, OutputOverlayLayoutMetrics.minimumLayerGap)
        XCTAssertFalse(bottomLogoFrame.intersects(lowerThirdFrame))
    }

    func testAllPlannedFramesStayInsideCanvas() {
        for size in [CGSize(width: 1280, height: 720), CGSize(width: 1920, height: 1080), CGSize(width: 3840, height: 2160)] {
            for position in CornerLogoPosition.allCases {
                let plan = OutputOverlayLayoutPlan.make(
                    canvasSize: size,
                    isTickerActive: true,
                    isCountdownActive: true,
                    isLowerThirdVisible: true,
                    isLogoReady: true,
                    logoPosition: position
                )

                for frame in [plan.tickerFrame, plan.countdownFrame, plan.lowerThirdFrame, plan.logoFrame].compactMap({ $0 }) {
                    XCTAssertGreaterThanOrEqual(frame.minX, 0)
                    XCTAssertGreaterThanOrEqual(frame.minY, 0)
                    XCTAssertLessThanOrEqual(frame.maxX, size.width)
                    XCTAssertLessThanOrEqual(frame.maxY, size.height)
                }
            }
        }
    }

    func testLegacyPlacementTestOnlyAPIIsRemoved() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/OutputOverlayLayoutMetrics.swift")

        XCTAssertFalse(source.contains("enum OutputOverlayPlacement"))
        XCTAssertFalse(source.contains("placements("))
    }

    private func tryUnwrap<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) -> T {
        guard let value else {
            XCTFail("Expected non-nil value", file: file, line: line)
            fatalError("Expected non-nil value")
        }
        return value
    }
}
