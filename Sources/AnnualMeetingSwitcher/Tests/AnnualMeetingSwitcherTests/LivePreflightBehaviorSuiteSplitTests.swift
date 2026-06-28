import XCTest

final class LivePreflightBehaviorSuiteSplitTests: XCTestCase {
    func testLivePreflightBehaviorSuiteIsSplitIntoFocusedFilesAndOffAllowlist() throws {
        let expectedFiles = [
            "LivePreflightSummaryTests.swift": 500,
            "LivePreflightPermissionTests.swift": 500,
            "LivePreflightRiskTests.swift": 500,
            "LivePreflightSupportTests.swift": 500,
            "LivePreflightPresentationReadinessTests.swift": 500,
            "LivePreflightTestSupport.swift": 250
        ]

        for (fileName, maxLineCount) in expectedFiles {
            let relativePath = "Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/\(fileName)"
            let lineCount = try sourceText(relativePath)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .count

            XCTAssertLessThanOrEqual(lineCount, maxLineCount, "\(fileName) should stay below its budget.")
        }

        let oldFilePath = "Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/LivePreflightTests.swift"
        if FileManager.default.fileExists(atPath: sourceURL(oldFilePath, repositoryRoot: try repositoryRoot()).path) {
            let lineCount = try sourceText(oldFilePath)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .count

            XCTAssertLessThan(lineCount, 250, "LivePreflightTests.swift should be deleted or reduced to a shell.")
        }

        let allowlist = try sourceText("docs/architecture/complexity-allowlist.tsv")
        XCTAssertFalse(allowlist.contains(oldFilePath))
    }
}
