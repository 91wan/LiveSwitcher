import XCTest

final class BGMRuntimeReducerSplitTests: XCTestCase {
    func testBGMRuntimeReducerHelpersAreSplitIntoFocusedFilesAndOffAllowlist() throws {
        XCTAssertLessThanOrEqual(try sourceLineCount("Runtime/BGMRuntimeReducer.swift"), 250)

        let reducerFiles = [
            "Runtime/BGM/BGMRuntimeSelectionReducer.swift",
            "Runtime/BGM/BGMRuntimePlaybackReducer.swift",
            "Runtime/BGM/BGMRuntimePanicReducer.swift",
            "Runtime/BGM/BGMRuntimeLibraryReducer.swift",
            "Runtime/BGM/BGMRuntimeProgressReducer.swift"
        ]

        for relativePath in reducerFiles {
            let url = sourceURL(relativePath, repositoryRoot: try repositoryRoot())
            guard FileManager.default.fileExists(atPath: url.path) else {
                XCTFail(relativePath)
                continue
            }
            XCTAssertLessThanOrEqual(try sourceLineCount(relativePath), 250, relativePath)
        }

        let allowlist = try sourceText("docs/architecture/complexity-allowlist.tsv")
        XCTAssertFalse(allowlist.contains("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/BGMRuntimeReducer.swift"))
    }

    private func sourceLineCount(_ relativePath: String) throws -> Int {
        try sourceText(relativePath)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .count
    }
}
