import XCTest

final class MonitorWallpaperTypographyConvergenceTests: XCTestCase {
    func testProgramMonitorUsesStudioTypeScaleInsteadOfRawSystemFontLiterals() throws {
        try assertUsesTypeScale(relativePath: "Views/ProgramMonitorView.swift")
    }

    func testWallpaperGalleryUsesStudioTypeScaleInsteadOfRawSystemFontLiterals() throws {
        try assertUsesTypeScale(relativePath: "Views/WallpaperGalleryRow.swift")
    }

    func testProgramThumbnailUsesStudioTypeScaleInsteadOfRawSystemFontLiterals() throws {
        try assertUsesTypeScale(relativePath: "Views/ThumbnailView.swift")
    }

    private func assertUsesTypeScale(relativePath: String) throws {
        let source = try sourceText(relativePath)

        XCTAssertFalse(source.contains(".font(.system(size:"))
        XCTAssertTrue(source.contains("StudioTheme.TypeScale"))
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
