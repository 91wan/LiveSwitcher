import XCTest

final class BGMPlaybackFacadeSplitTests: XCTestCase {
    func testBGMPlaybackFacadeWiringIsSplitIntoFocusedFilesAndOffAllowlist() throws {
        XCTAssertLessThanOrEqual(try sourceLineCount("ViewModel+BGMRuntimePlayback.swift"), 250)

        let requiredFiles = [
            "BGMPlayback/BGMPlayerPreparation.swift",
            "BGMPlayback/BGMPlayerTransport.swift",
            "BGMPlayback/BGMPlayerFade.swift",
            "BGMPlayback/BGMPlayerProgress.swift",
            "BGMPlayback/BGMFallbackPlayerBridge.swift",
            "BGMPlayback/BGMGenerationGuard.swift"
        ]

        for relativePath in requiredFiles {
            _ = try source(relativePath)
            XCTAssertLessThanOrEqual(try sourceLineCount(relativePath), 250, relativePath)
        }

        let allowlist = try repositorySource("docs/architecture/complexity-allowlist.tsv")
        XCTAssertFalse(allowlist.contains("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+BGMRuntimePlayback.swift"))
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
