import XCTest

final class LowerThirdOverlaySplitTests: XCTestCase {
    func testLowerThirdOverlayRenderersAreSplitIntoFocusedFilesAndOffAllowlist() throws {
        let overlayFiles = [
            "Views/OutputOverlays/LowerThirdView.swift",
            "Views/OutputOverlays/TickerTrackGeometry.swift",
            "Views/OutputOverlays/TickerEngine.swift",
            "Views/OutputOverlays/TickerOverlay.swift"
        ]
        let allowlist = try sourceText("docs/architecture/complexity-allowlist.tsv")

        for relativePath in overlayFiles {
            let url = sourceURL(relativePath, repositoryRoot: try repositoryRoot())
            guard FileManager.default.fileExists(atPath: url.path) else {
                XCTFail(relativePath)
                continue
            }
            XCTAssertLessThanOrEqual(try sourceLineCount(relativePath), 250, relativePath)
            XCTAssertFalse(allowlist.contains("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/\(relativePath)"), relativePath)
        }
    }

    private func sourceLineCount(_ relativePath: String) throws -> Int {
        try sourceText(relativePath)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .count
    }
}
