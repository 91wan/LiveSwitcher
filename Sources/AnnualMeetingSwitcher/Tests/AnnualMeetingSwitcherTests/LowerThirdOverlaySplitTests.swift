import XCTest

final class LowerThirdOverlaySplitTests: XCTestCase {
    func testLowerThirdOverlayRenderersAreSplitIntoFocusedFilesAndOffAllowlist() throws {
        XCTAssertLessThanOrEqual(try sourceLineCount("Views/LowerThirdOverlay.swift"), 250)

        let overlayFiles = [
            "Views/OutputOverlays/LowerThirdView.swift",
            "Views/OutputOverlays/TickerTrackGeometry.swift",
            "Views/OutputOverlays/TickerEngine.swift",
            "Views/OutputOverlays/TickerOverlay.swift"
        ]

        for relativePath in overlayFiles {
            let url = sourceURL(relativePath, repositoryRoot: try repositoryRoot())
            guard FileManager.default.fileExists(atPath: url.path) else {
                XCTFail(relativePath)
                continue
            }
            XCTAssertLessThanOrEqual(try sourceLineCount(relativePath), 250, relativePath)
        }

        let allowlist = try sourceText("docs/architecture/complexity-allowlist.tsv")
        XCTAssertFalse(allowlist.contains("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LowerThirdOverlay.swift"))
    }

    private func sourceLineCount(_ relativePath: String) throws -> Int {
        try sourceText(relativePath)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .count
    }
}
