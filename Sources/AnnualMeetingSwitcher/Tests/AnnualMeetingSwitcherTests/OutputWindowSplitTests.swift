import XCTest

final class OutputWindowSplitTests: XCTestCase {
    func testOutputWindowBridgeIsSplitIntoFocusedFilesAndOffAllowlist() throws {
        XCTAssertLessThanOrEqual(try sourceLineCount("Output/OutputWindowController.swift"), 250)

        let outputFiles = [
            "Output/OutputWindowPlacement.swift",
            "Output/OutputView.swift",
            "Output/OutputVideoPlayerView.swift",
            "Output/OutputHTMLLayer.swift",
            "Output/MonitorVideoPlayerView.swift"
        ]

        for relativePath in outputFiles {
            let url = sourceURL(relativePath, repositoryRoot: try repositoryRoot())
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), relativePath)
            XCTAssertLessThanOrEqual(try sourceLineCount(relativePath), 250, relativePath)
        }

        let allowlist = try sourceText("docs/architecture/complexity-allowlist.tsv")
        XCTAssertFalse(allowlist.contains("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Output/OutputWindowController.swift"))
    }

    private func sourceLineCount(_ relativePath: String) throws -> Int {
        try sourceText(relativePath)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .count
    }
}
