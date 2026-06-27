import XCTest
@testable import LiveSwitcher

final class LiveModePerformanceHygieneTests: XCTestCase {
    func testLiveModeAndOutputDoNotSynchronouslyLoadImagesInBody() throws {
        let liveMode = try liveModeSurfaceSource()
        let output = try sourceText("Output/OutputWindowController.swift")
        let wallpaper = try sourceText("Views/WallpaperGalleryRow.swift")

        XCTAssertFalse(liveMode.contains("NSImage(contentsOf:"))
        XCTAssertFalse(output.contains("NSImage(contentsOf: url)"))
        XCTAssertFalse(wallpaper.contains("NSImage(contentsOf:"))
        XCTAssertTrue(liveMode.contains("AsyncLocalImage"))
        XCTAssertFalse(output.contains("AsyncLocalImage"))
        XCTAssertFalse(output.contains("Data(contentsOf:"))
        XCTAssertTrue(wallpaper.contains("AsyncLocalImage(url: url)"))
    }

    func testLiveLayoutWidthStillFitsMinimumWindow() {
        let total = LiveModeLayoutMetrics.sourceRailWidth
            + LiveModeLayoutMetrics.quickRailWidth
            + LiveModeLayoutMetrics.minimumProgramColumnWidth
            + LiveModeLayoutMetrics.horizontalContentPadding
            + LiveModeLayoutMetrics.mainColumnSpacing * 2

        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.quickRailWidth, 250)
        XCTAssertLessThanOrEqual(total, 1360)
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func liveModeSurfaceSource() throws -> String {
        try [
            "Views/LiveModeView.swift",
            "Views/LiveSourceRail.swift",
            "Views/LiveQuickRail.swift",
            "Views/LiveWallpaperPickerThumb.swift"
        ]
        .map { try sourceText($0) }
        .joined(separator: "\n")
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
