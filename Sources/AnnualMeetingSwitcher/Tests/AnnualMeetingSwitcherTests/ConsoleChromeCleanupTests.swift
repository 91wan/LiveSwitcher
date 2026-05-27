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
        XCTAssertFalse(source.contains("ToolbarActionModel"))
        XCTAssertFalse(source.contains("speaker"))
        XCTAssertFalse(source.contains("ppt"))
        XCTAssertTrue(source.contains("panicButton"))
        XCTAssertTrue(source.contains("preflightButton"))
        XCTAssertTrue(source.contains("helpButton"))
    }

    func testTopChromeShowsNavigationAffordancesForSetupAndPreflight() throws {
        let toolbar = try sourceText("Views/MainToolbar.swift")
        let content = try sourceText("ContentView.swift")

        XCTAssertTrue(toolbar.contains("chevron.down"))
        XCTAssertTrue(content.contains("title: \"← 准备\""))
        XCTAssertTrue(content.contains("systemImage: \"chevron.left\""))
        XCTAssertTrue(content.contains("accessibilityHint(\"返回准备模式\")"))
    }

    func testStaleToolbarActionModelWasRemoved() throws {
        XCTAssertFalse(sourceExists("Models/ToolbarActionModel.swift"))
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

    private func sourceExists(_ relativePath: String) -> Bool {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return true
            }
        }
        return false
    }
}
