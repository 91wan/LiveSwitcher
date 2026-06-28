import XCTest

final class AudioRuntimeOwnershipSuiteSplitTests: XCTestCase {
    func testAudioRuntimeOwnershipSuiteIsSplitIntoFocusedFiles() throws {
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
        "Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/AudioRuntimeOwnershipTests.swift"
    }

    private var splitFilePaths: [String] {
        [
            "Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/AudioRuntimeVolumeOwnershipTests.swift",
            "Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/AudioRuntimeMuteOwnershipTests.swift",
            "Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/AudioRuntimeSpeakerModeOwnershipTests.swift",
            "Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/AudioRuntimeBGMTakeoverOwnershipTests.swift",
            "Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/AudioRuntimeOwnershipTestSupport.swift"
        ]
    }
}
