import XCTest
@testable import LiveSwitcher

final class MonitorChromeVisibilityTests: XCTestCase {
    func testChromeStaysVisibleWhenNotPlayingRegardlessOfHoverOrBroadcasting() {
        for hovering in [false, true] {
            for broadcasting in [false, true] {
                let model = MonitorChromeVisibility.make(
                    isPlaying: false,
                    isHovering: hovering,
                    isBroadcasting: broadcasting,
                    isTickerActive: false
                )

                XCTAssertEqual(model.inlineChromeOpacity, 1)
                XCTAssertTrue(model.inlineChromeAllowsHitTesting)
                XCTAssertFalse(model.showsCompactLiveIndicator)
                XCTAssertEqual(model.compactLiveIndicatorOpacity, 0)
            }
        }
    }

    func testPlayingWithoutHoverHidesInlineChrome() {
        let model = MonitorChromeVisibility.make(
            isPlaying: true,
            isHovering: false,
            isBroadcasting: false,
            isTickerActive: false
        )

        XCTAssertEqual(model.inlineChromeOpacity, 0)
        XCTAssertFalse(model.inlineChromeAllowsHitTesting)
        XCTAssertFalse(model.showsCompactLiveIndicator)
    }

    func testPlayingWithHoverRestoresInlineChrome() {
        let model = MonitorChromeVisibility.make(
            isPlaying: true,
            isHovering: true,
            isBroadcasting: true,
            isTickerActive: false
        )

        XCTAssertEqual(model.inlineChromeOpacity, 1)
        XCTAssertTrue(model.inlineChromeAllowsHitTesting)
        XCTAssertFalse(model.showsCompactLiveIndicator)
    }

    func testBroadcastingWhilePlayingAndNotHoveredShowsCompactLiveIndicator() {
        let model = MonitorChromeVisibility.make(
            isPlaying: true,
            isHovering: false,
            isBroadcasting: true,
            isTickerActive: false
        )

        XCTAssertEqual(model.inlineChromeOpacity, 0)
        XCTAssertFalse(model.inlineChromeAllowsHitTesting)
        XCTAssertTrue(model.showsCompactLiveIndicator)
        XCTAssertEqual(model.compactLiveIndicatorOpacity, 1)
    }

    func testTickerActiveHidesInlineChromeEvenWhenMediaIsNotPlaying() {
        let hidden = MonitorChromeVisibility.make(
            isPlaying: false,
            isHovering: false,
            isBroadcasting: true,
            isTickerActive: true
        )
        XCTAssertEqual(hidden.inlineChromeOpacity, 0)
        XCTAssertFalse(hidden.inlineChromeAllowsHitTesting)
        XCTAssertTrue(hidden.showsCompactLiveIndicator)

        let hovered = MonitorChromeVisibility.make(
            isPlaying: false,
            isHovering: true,
            isBroadcasting: true,
            isTickerActive: true
        )
        XCTAssertEqual(hovered.inlineChromeOpacity, 1)
        XCTAssertTrue(hovered.inlineChromeAllowsHitTesting)
        XCTAssertFalse(hovered.showsCompactLiveIndicator)
    }

    func testProgramMonitorViewUsesVisibilityModelAndHoverState() throws {
        let source = try sourceText("Views/ProgramMonitorView.swift")

        XCTAssertTrue(source.contains("@State private var isHoveringPreviewDeck"))
        XCTAssertTrue(source.contains("MonitorChromeVisibility.make("))
        XCTAssertTrue(source.contains("isTickerActive: viewModel.isTickerActive"))
        XCTAssertTrue(source.contains(".onHover { hovering in"))
        XCTAssertTrue(source.contains("compactLiveIndicator"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
