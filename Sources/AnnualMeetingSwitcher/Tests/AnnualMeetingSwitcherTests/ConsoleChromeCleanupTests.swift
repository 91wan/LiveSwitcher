import XCTest

final class ConsoleChromeCleanupTests: XCTestCase {
    func testContentViewDoesNotKeepLowValueBottomStatusBar() throws {
        let source = try sourceText("ContentView.swift")

        XCTAssertFalse(source.contains("StatusBar()"))
        XCTAssertFalse(source.contains("struct StatusBar"))
    }

    func testMainToolbarHasSingleActionPathWithoutLegacyFixedWidths() throws {
        let source = try sourceText("Views/MainToolbar.swift")

        XCTAssertFalse(source.contains("ViewThatFits(in: .horizontal)"))
        XCTAssertFalse(source.contains("compactToolbarButton"))
        XCTAssertFalse(source.contains("compactPreflightButton"))
        XCTAssertFalse(source.contains("frame(width: 112"))
        XCTAssertTrue(source.contains("panicButton"))
        XCTAssertTrue(source.contains("preflightButton"))
        XCTAssertTrue(source.contains("helpButton"))
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
