import XCTest

final class AppShellStaticTests: XCTestCase {
    func testContentViewIsSplitIntoFocusedAppShellFilesAndOffAllowlist() throws {
        XCTAssertLessThanOrEqual(try sourceLineCount("ContentView.swift"), 250)

        let appShellFiles = [
            "Views/AppShell/ConsoleChromeView.swift",
            "Views/AppShell/ConsoleModeCluster.swift",
            "Views/AppShell/PrimaryNavigationBar.swift",
            "Views/AppShell/RunDeskLayout.swift",
            "Views/AppShell/ActiveConsoleLayer.swift",
            "Views/AppShell/PanicChromeContainer.swift",
            "Views/AppShell/GlobalKeyMonitor.swift"
        ]

        for relativePath in appShellFiles {
            let url = sourceURL(relativePath, repositoryRoot: try repositoryRoot())
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), relativePath)
            XCTAssertLessThanOrEqual(try sourceLineCount(relativePath), 250, relativePath)
        }

        let allowlist = try sourceText("docs/architecture/complexity-allowlist.tsv")
        XCTAssertFalse(allowlist.contains("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ContentView.swift"))
    }

    private func sourceLineCount(_ relativePath: String) throws -> Int {
        try sourceText(relativePath)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .count
    }
}
