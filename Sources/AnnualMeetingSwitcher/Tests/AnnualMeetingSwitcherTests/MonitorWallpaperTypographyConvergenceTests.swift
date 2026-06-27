import XCTest

final class MonitorWallpaperTypographyConvergenceTests: XCTestCase {
    func testProgramMonitorUsesStudioTypeScaleInsteadOfRawSystemFontLiterals() throws {
        let source = try [
            "Views/ProgramMonitor/ProgramMonitorView.swift",
            "Views/ProgramMonitor/ProgramMonitorPreviewDeck.swift",
            "Views/ProgramMonitor/ProgramMonitorChrome.swift",
            "Views/ProgramMonitor/ProgramMonitorMediaLayer.swift",
            "Views/ProgramMonitor/ProgramMonitorWallpaperTray.swift",
            "Views/ProgramMonitor/ProgramMonitorBlackoutOverlay.swift"
        ].map(sourceText).joined(separator: "\n")

        assertUsesTypeScale(source)
    }

    func testWallpaperGalleryUsesStudioTypeScaleInsteadOfRawSystemFontLiterals() throws {
        try assertUsesTypeScale(relativePath: "Views/WallpaperGalleryRow.swift")
    }

    func testProgramThumbnailUsesStudioTypeScaleInsteadOfRawSystemFontLiterals() throws {
        try assertUsesTypeScale(relativePath: "Views/ThumbnailView.swift")
    }

    private func assertUsesTypeScale(_ source: String) {
        XCTAssertFalse(source.contains(".font(.system(size:"))
        XCTAssertTrue(source.contains("StudioTheme.TypeScale"))
    }

    private func assertUsesTypeScale(relativePath: String) throws {
        assertUsesTypeScale(try sourceText(relativePath))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try LiveSwitcherTests.sourceText(relativePath, filePath: #filePath)
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
