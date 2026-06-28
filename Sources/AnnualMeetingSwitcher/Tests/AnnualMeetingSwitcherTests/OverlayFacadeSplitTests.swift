import XCTest

final class OverlayFacadeSplitTests: XCTestCase {
    func testOverlayFacadeWiringIsSplitIntoFocusedFilesAndOffAllowlist() throws {
        XCTAssertLessThanOrEqual(try sourceLineCount("ViewModel+Overlay.swift"), 250)

        let requiredFiles = [
            "OverlayFacade/LowerThirdPresetFacade.swift",
            "OverlayFacade/CountdownPresetFacade.swift",
            "OverlayFacade/TickerPresetFacade.swift",
            "OverlayFacade/OverlayComposerFacade.swift",
            "OverlayFacade/OverlayImportExportFacade.swift",
            "OverlayFacade/OverlayLiveStateFacade.swift"
        ]

        for relativePath in requiredFiles {
            _ = try source(relativePath)
            XCTAssertLessThanOrEqual(try sourceLineCount(relativePath), 250, relativePath)
        }

        let allowlist = try repositorySource("docs/architecture/complexity-allowlist.tsv")
        XCTAssertFalse(allowlist.contains("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Overlay.swift"))
    }

    private func sourceLineCount(_ relativePath: String) throws -> Int {
        try source(relativePath)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .count
    }

    private func source(_ relativePath: String) throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/\(relativePath)")
    }
}
