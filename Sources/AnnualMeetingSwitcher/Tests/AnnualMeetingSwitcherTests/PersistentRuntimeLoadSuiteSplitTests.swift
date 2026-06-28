import XCTest

final class PersistentStateRuntimeLoadSuiteSplitTests: XCTestCase {
    func testPersistentRuntimeLoadSuiteIsSplitIntoFocusedFiles() throws {
        if let original = try optionalRepositorySource(originalPath) {
            XCTAssertLessThan(
                original.split(separator: "\n", omittingEmptySubsequences: false).count,
                250,
                originalPath
            )
        }

        for path in splitFilePaths {
            let source = try XCTUnwrap(try optionalRepositorySource(path), path)
            XCTAssertLessThan(
                source.split(separator: "\n", omittingEmptySubsequences: false).count,
                path.hasSuffix("TestSupport.swift") ? 250 : 500,
                path
            )
        }
    }

    private var originalPath: String {
        "Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/PersistentStateRuntimeLoadBoundaryTests.swift"
    }

    private var splitFilePaths: [String] {
        [
            "Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/PersistentRuntimeLoadQueueTests.swift",
            "Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/PersistentRuntimeLoadBGMTests.swift",
            "Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/PersistentRuntimeLoadAudioTests.swift",
            "Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/PersistentRuntimeLoadOverlayTests.swift",
            "Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/PersistentRuntimeLoadPreferencesTests.swift",
            "Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/PersistentRuntimeLoadBoundaryTestSupport.swift"
        ]
    }
}
