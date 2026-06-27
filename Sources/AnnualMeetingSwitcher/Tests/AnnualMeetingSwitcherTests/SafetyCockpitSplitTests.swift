import XCTest

final class SafetyCockpitSplitTests: XCTestCase {
    func testSafetyCockpitFilesStayFocusedAndOffComplexityAllowlist() throws {
        let expectedFiles = [
            "Views/Support/SafetyCockpitView.swift",
            "Views/Support/SafetyCockpitHeader.swift",
            "Views/Support/SafetyCockpitStatusGrid.swift",
            "Views/Support/SafetyCockpitRiskRow.swift",
            "Views/Support/SafetyCockpitSupportActions.swift"
        ]

        for relativePath in expectedFiles {
            XCTAssertTrue(try sourceFileExists(relativePath), "\(relativePath) should exist after the split.")
            let lineCount = try sourceText(relativePath).split(separator: "\n", omittingEmptySubsequences: false).count
            XCTAssertLessThan(lineCount, 250, "\(relativePath) should stay below the per-file complexity budget.")
        }

        let allowlist = try String(
            contentsOf: repositoryRoot(filePath: #filePath).appendingPathComponent("docs/architecture/complexity-allowlist.tsv"),
            encoding: .utf8
        )
        XCTAssertFalse(allowlist.contains("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/SafetyCockpitView.swift"))
        XCTAssertFalse(allowlist.contains("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/Support/SafetyCockpitView.swift"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try LiveSwitcherTests.sourceText(relativePath, filePath: #filePath)
    }

    private func sourceFileExists(_ relativePath: String) throws -> Bool {
        FileManager.default.fileExists(atPath: try sourceURL(relativePath).path)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        try repositoryRoot(filePath: #filePath)
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
            .appendingPathComponent(relativePath)
    }
}
