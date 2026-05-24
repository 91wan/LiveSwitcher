import XCTest

final class PreflightTypographyConvergenceTests: XCTestCase {
    func testPreflightPopoverUsesStudioTypeScaleInsteadOfRawSystemFontLiterals() throws {
        let source = try sourceText("Views/PreflightPopoverView.swift")

        XCTAssertFalse(source.contains(".font(.system(size:"))
        XCTAssertTrue(source.contains("StudioTheme.TypeScale"))
    }

    func testSafetyCockpitUsesStudioTypeScaleInsteadOfRawSystemFontLiterals() throws {
        let source = try sourceText("Views/SafetyCockpitView.swift")

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
