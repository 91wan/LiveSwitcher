import XCTest

final class LiveRuntimeStateSplitTests: XCTestCase {
    func testLiveRuntimeStateModelsAreSplitIntoFocusedFilesAndOffAllowlist() throws {
        XCTAssertLessThanOrEqual(try sourceLineCount("Runtime/LiveRuntimeState.swift"), 250)

        let runtimeFiles = [
            "Runtime/LiveRuntimeBridgeMode.swift",
            "Runtime/LiveRuntimeDomain.swift",
            "Runtime/State/ProgramRuntimeState.swift",
            "Runtime/State/MediaRuntimeState.swift",
            "Runtime/State/BGMRuntimeState.swift",
            "Runtime/State/AudioRuntimeState.swift",
            "Runtime/State/PanicRuntimeState.swift",
            "Runtime/State/PPTRuntimeState.swift",
            "Runtime/State/ProjectionRuntimeState.swift",
            "Runtime/State/AutomationRuntimeState.swift",
            "Runtime/State/PresentationQueryRuntimeState.swift",
            "Runtime/State/LiveRuntimePreferenceState.swift",
            "Runtime/State/SupportRuntimeState.swift"
        ]

        for relativePath in runtimeFiles {
            let url = sourceURL(relativePath, repositoryRoot: try repositoryRoot())
            guard FileManager.default.fileExists(atPath: url.path) else {
                XCTFail(relativePath)
                continue
            }
            XCTAssertLessThanOrEqual(try sourceLineCount(relativePath), 250, relativePath)
        }

        let allowlist = try sourceText("docs/architecture/complexity-allowlist.tsv")
        XCTAssertFalse(allowlist.contains("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeState.swift"))
    }

    private func sourceLineCount(_ relativePath: String) throws -> Int {
        try sourceText(relativePath)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .count
    }
}
