import XCTest

final class LiveRuntimeReducerDispatchSplitTests: XCTestCase {
    func testLiveRuntimeReducerDispatchersAreSplitIntoFocusedFilesAndOffAllowlist() throws {
        XCTAssertLessThanOrEqual(try sourceLineCount("Runtime/LiveRuntimeReducer.swift"), 250)

        let dispatcherFiles = [
            "Runtime/Reducers/ProgramRuntimeActionDispatcher.swift",
            "Runtime/Reducers/MediaRuntimeActionDispatcher.swift",
            "Runtime/Reducers/AudioRuntimeActionDispatcher.swift",
            "Runtime/Reducers/BGMRuntimeActionDispatcher.swift",
            "Runtime/Reducers/PanicProjectionRuntimeActionDispatcher.swift",
            "Runtime/Reducers/PreferenceRuntimeActionDispatcher.swift",
            "Runtime/Reducers/AutomationRuntimeActionDispatcher.swift",
            "Runtime/Reducers/SupportRuntimeActionDispatcher.swift"
        ]

        for relativePath in dispatcherFiles {
            let url = sourceURL(relativePath, repositoryRoot: try repositoryRoot())
            guard FileManager.default.fileExists(atPath: url.path) else {
                XCTFail(relativePath)
                continue
            }
            XCTAssertLessThanOrEqual(try sourceLineCount(relativePath), 250, relativePath)
        }

        let allowlist = try sourceText("docs/architecture/complexity-allowlist.tsv")
        XCTAssertFalse(allowlist.contains("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift"))
    }

    private func sourceLineCount(_ relativePath: String) throws -> Int {
        try sourceText(relativePath)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .count
    }
}
