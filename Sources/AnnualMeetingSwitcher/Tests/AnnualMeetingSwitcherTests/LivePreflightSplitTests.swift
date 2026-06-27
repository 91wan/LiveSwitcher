import Foundation
import XCTest

final class LivePreflightSplitTests: XCTestCase {
    func testLivePreflightModelsAreSplitIntoFocusedFilesAndOffAllowlist() throws {
        let oldModel = sourceURL("Models/LivePreflight.swift", repositoryRoot: try repositoryRoot())
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: oldModel.path),
            "LivePreflight models should live under Models/Preflight instead of the old monolithic file."
        )

        let modelFiles = [
            "Models/Preflight/LivePreflight.swift",
            "Models/Preflight/PreflightCheck.swift",
            "Models/Preflight/PreflightPermissionModel.swift",
            "Models/Preflight/PreflightSummaryModel.swift",
            "Models/Preflight/PreflightRiskModel.swift",
            "Models/Preflight/PreflightSupportModel.swift"
        ]

        for relativePath in modelFiles {
            let url = sourceURL(relativePath, repositoryRoot: try repositoryRoot())
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), relativePath)
            XCTAssertLessThanOrEqual(try sourceLineCount(relativePath), 250, relativePath)
        }

        let allowlist = try sourceText("docs/architecture/complexity-allowlist.tsv")
        XCTAssertFalse(allowlist.contains("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/LivePreflight.swift"))
    }

    private func sourceLineCount(_ relativePath: String) throws -> Int {
        try sourceText(relativePath)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .count
    }
}
