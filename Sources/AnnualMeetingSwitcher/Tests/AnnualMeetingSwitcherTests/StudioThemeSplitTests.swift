import XCTest

final class StudioThemeSplitTests: XCTestCase {
    func testStudioThemeTokensAreSplitIntoFocusedFilesAndOffAllowlist() throws {
        XCTAssertLessThanOrEqual(try sourceLineCount("Views/StudioTheme.swift"), 250)

        let themeFiles = [
            "Views/Theme/StudioTheme+Colors.swift",
            "Views/Theme/StudioTheme+Typography.swift",
            "Views/Theme/StudioTheme+Layout.swift",
            "Views/Theme/StudioTheme+Status.swift",
            "Views/Theme/StudioTheme+Components.swift"
        ]

        for relativePath in themeFiles {
            let url = sourceURL(relativePath, repositoryRoot: try repositoryRoot())
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), relativePath)
            XCTAssertLessThanOrEqual(try sourceLineCount(relativePath), 250, relativePath)
        }

        let allowlist = try sourceText("docs/architecture/complexity-allowlist.tsv")
        XCTAssertFalse(allowlist.contains("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/StudioTheme.swift"))
    }

    private func sourceLineCount(_ relativePath: String) throws -> Int {
        try sourceText(relativePath)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .count
    }
}
