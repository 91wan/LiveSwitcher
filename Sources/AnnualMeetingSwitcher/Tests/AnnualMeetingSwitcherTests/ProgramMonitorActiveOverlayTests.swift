import XCTest
@testable import LiveSwitcher

final class ProgramMonitorActiveOverlayTests: XCTestCase {
    func testOutputAndProgramMonitorUseSharedActiveOverlayLayer() throws {
        let output = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Output/OutputWindowController.swift")
        let monitor = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitorView.swift")

        XCTAssertTrue(output.contains("ActiveProgramOverlayLayer("))
        XCTAssertTrue(monitor.contains("ActiveProgramOverlayLayer("))
        XCTAssertFalse(output.contains("private struct OutputOverlayLayer"))
        XCTAssertFalse(monitor.contains("OverlayLivePreviewCanvas"))
    }

    func testProgramMonitorUsesLogicalOutputCanvasForSharedOverlay() throws {
        let monitor = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitorView.swift")

        XCTAssertTrue(monitor.contains("OutputDisplayState.make(from: viewModel)"))
        XCTAssertTrue(monitor.contains("ProgramMonitorOverlayCanvas.logicalSize"))
        XCTAssertTrue(monitor.contains("cornerLogoImage: viewModel.cornerLogoImage"))
    }

    func testProgramMonitorRemovesSeparateLogoOverlayTruth() throws {
        let monitor = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitorView.swift")

        XCTAssertFalse(monitor.contains("monitorCornerLogoOverlay"))
        XCTAssertFalse(monitor.contains("monitorCornerLogoImage"))
        XCTAssertFalse(monitor.contains("viewModel.cornerLogoPosition.monitorPadding"))
    }

    func testSharedActiveOverlayLayerOwnsOverlayElementsAndZIndexContract() throws {
        let layer = try requiredSourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ActiveProgramOverlayLayer.swift")

        XCTAssertTrue(layer.contains("struct ActiveProgramOverlayLayer"))
        XCTAssertTrue(layer.contains("OutputOverlayLayoutPlan.make("))
        XCTAssertTrue(layer.contains("CountdownOverlay()"))
        XCTAssertTrue(layer.contains("TickerOverlay()"))
        XCTAssertTrue(layer.contains("LowerThirdView("))
        XCTAssertTrue(layer.contains("OutputCornerLogoLayer("))
        XCTAssertTrue(layer.contains("OutputLayerZIndex.countdown"))
        XCTAssertTrue(layer.contains("OutputLayerZIndex.ticker"))
        XCTAssertTrue(layer.contains("OutputLayerZIndex.lowerThird"))
        XCTAssertTrue(layer.contains("OutputLayerZIndex.cornerLogo"))
        XCTAssertTrue(layer.contains("OutputLayerZIndex.fadeToBlack"))
        XCTAssertTrue(layer.contains("OutputLayerZIndex.panic"))
    }

    func testEightOverlayCombinationsResolveVisibleOutputFrames() {
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

                    XCTAssertEqual(plan.tickerFrame != nil, ticker)
                    XCTAssertEqual(plan.countdownFrame != nil, countdown)
                    XCTAssertEqual(plan.lowerThirdFrame != nil, lowerThird)
                    XCTAssertNil(plan.logoFrame)
                }
            }
        }
    }

    func testTickerOverlayStopsTimerWhenSharedLayerUnmounts() throws {
        let ticker = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LowerThirdOverlay.swift")

        XCTAssertTrue(ticker.contains("@StateObject private var engine = TickerEngine()"))
        XCTAssertTrue(ticker.contains(".onDisappear {\n            engine.stop()\n        }"))
    }

    private func requiredSourceText(_ relativePath: String) throws -> String {
        let url = try repositoryRoot().appendingPathComponent(relativePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Missing required source file: \(relativePath)")
        guard FileManager.default.fileExists(atPath: url.path) else { return "" }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
