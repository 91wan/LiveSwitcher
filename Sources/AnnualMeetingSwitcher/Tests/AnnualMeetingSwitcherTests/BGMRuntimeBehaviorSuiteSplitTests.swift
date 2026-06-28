import XCTest

final class BGMRuntimeReducerBehaviorSuiteSplitTests: XCTestCase {
    func testBGMRuntimeReducerBehaviorSuiteIsSplitIntoFocusedFilesAndOffAllowlist() throws {
        let expectedFiles = [
            "BGMRuntimeSelectionTests.swift": 500,
            "BGMRuntimePlaybackTests.swift": 500,
            "BGMRuntimePanicTests.swift": 500,
            "BGMRuntimeLibraryTests.swift": 500,
            "BGMRuntimeProgressTests.swift": 500,
            "BGMRuntimeReducerTestSupport.swift": 250
        ]

        for (fileName, maxLineCount) in expectedFiles {
            let relativePath = "Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/\(fileName)"
            let lineCount = try sourceText(relativePath)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .count

            XCTAssertLessThanOrEqual(lineCount, maxLineCount, "\(fileName) should stay below its budget.")
        }

        let oldFilePath = "Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/BGMRuntimeReducerBehaviorTests.swift"
        if FileManager.default.fileExists(atPath: sourceURL(oldFilePath, repositoryRoot: try repositoryRoot()).path) {
            let lineCount = try sourceText(oldFilePath)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .count

            XCTAssertLessThan(lineCount, 250, "BGMRuntimeReducerBehaviorTests.swift should be deleted or reduced to a shell.")
        }

        let allowlist = try sourceText("docs/architecture/complexity-allowlist.tsv")
        XCTAssertFalse(allowlist.contains(oldFilePath))
    }
}
