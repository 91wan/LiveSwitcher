import XCTest
@testable import LiveSwitcher

final class ProgramMonitorActiveOverlayTests: XCTestCase {
    func testOutputAndProgramMonitorUseSharedActiveOverlayLayer() throws {
        let output = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Output/OutputWindowController.swift")
        let monitor = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitor/ProgramMonitorPreviewDeck.swift")

        XCTAssertTrue(output.contains("ActiveProgramOverlayLayer("))
        XCTAssertTrue(monitor.contains("ActiveProgramOverlayLayer("))
        XCTAssertFalse(output.contains("private struct OutputOverlayLayer"))
        XCTAssertFalse(monitor.contains("OverlayLivePreviewCanvas"))
    }

    func testProgramMonitorUsesLogicalOutputCanvasForSharedOverlay() throws {
        let monitor = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitor/ProgramMonitorPreviewDeck.swift")

        XCTAssertTrue(monitor.contains("OutputDisplayState.make(from: viewModel)"))
        XCTAssertTrue(monitor.contains("ProgramMonitorOverlayCanvas.logicalSize"))
        XCTAssertTrue(monitor.contains("cornerLogoImage: viewModel.cornerLogoImage"))
    }

    func testProgramMonitorOwnsLocalBlackoutStatusChromeButOutputDoesNot() throws {
        let output = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Output/OutputWindowController.swift")
        let monitor = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitor/ProgramMonitorPreviewDeck.swift")
        let blackoutOverlay = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitor/ProgramMonitorBlackoutOverlay.swift")
        let layer = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ActiveProgramOverlayLayer.swift")

        XCTAssertTrue(monitor.contains("blackoutStatusOverlay"))
        XCTAssertTrue(monitor.contains("ProgramMonitorBlackoutStatusModel.make("))
        XCTAssertTrue(monitor.contains("var monitorOutputDisplayState: OutputDisplayState"))
        XCTAssertTrue(monitor.contains("isFadeToBlackActive: monitorOutputDisplayState.isFadeToBlackActive"))
        XCTAssertTrue(monitor.contains("isPanicMode: monitorOutputDisplayState.isPanicMode"))
        XCTAssertFalse(monitor.contains("isPanicMode: viewModel.isPanicMode"))
        XCTAssertTrue(blackoutOverlay.contains("monitorAccessibilityLabel"))

        XCTAssertFalse(output.contains("ProgramMonitorBlackoutStatusModel"))
        XCTAssertFalse(output.contains("blackoutStatusOverlay"))
        XCTAssertFalse(output.contains("切黑中"))
        XCTAssertFalse(output.contains("紧急切黑"))

        XCTAssertTrue(layer.contains("if displayState.isFadeToBlackActive"))
        XCTAssertTrue(layer.contains("if displayState.isPanicMode"))
        XCTAssertTrue(layer.contains("PanicLayer()"))
    }

    func testProgramMonitorCentersAndEnlargesLocalBlackoutStatusChrome() throws {
        let monitor = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitor/ProgramMonitorPreviewDeck.swift")
        let blackoutOverlay = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitor/ProgramMonitorBlackoutOverlay.swift")

        XCTAssertTrue(monitor.contains(".overlay(alignment: .center)"))
        XCTAssertFalse(monitor.contains(".overlay(alignment: .topTrailing) {\n            if blackoutStatusModel.kind != .none"))
        XCTAssertTrue(blackoutOverlay.contains("VStack(alignment: .center"))
        XCTAssertTrue(blackoutOverlay.contains(".font(StudioTheme.TypeScale.title.weight(.black))"))
        XCTAssertTrue(blackoutOverlay.contains(".font(StudioTheme.TypeScale.heading.weight(.semibold))"))
        XCTAssertTrue(blackoutOverlay.contains(".multilineTextAlignment(.center)"))
    }

    func testProgramMonitorRemovesSeparateLogoOverlayTruth() throws {
        let monitor = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitor/ProgramMonitorPreviewDeck.swift")

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
