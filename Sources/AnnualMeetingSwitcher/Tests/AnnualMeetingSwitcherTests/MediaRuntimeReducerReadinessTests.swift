import XCTest
@testable import LiveSwitcher

final class MediaRuntimeReducerReadinessTests: XCTestCase {
    func testMediaRuntimeReducerExistsAfterExtraction() throws {
        let root = try repositoryRoot()
        let path = root.appendingPathComponent(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/MediaRuntimeReducer.swift"
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: path.path))
    }

    func testMediaReducerExtractionIsDocumentedAsCurrentRuntimeOwnership() throws {
        let docs = try repositorySource("docs/architecture/runtime-ownership.md")

        XCTAssertTrue(docs.contains("MediaRuntimeReducer"))
        XCTAssertTrue(docs.contains("Media Runtime mutation logic lives in `MediaRuntimeReducer.swift`"))
        XCTAssertTrue(docs.contains("Audio runtime mutation logic lives in `AudioRuntimeReducer.swift`"))
        XCTAssertFalse(docs.contains("AudioRuntimeReducer extraction remains future work"))
    }

    func testLiveRuntimeReducerRoutesMediaMutationAfterExtraction() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/Reducers/MediaRuntimeActionDispatcher.swift"
        )

        XCTAssertTrue(source.contains("case .operatorRestartedCurrentMedia"))
        XCTAssertTrue(source.contains("guard LiveRuntimeReducer.isRuntimeOwned(.media"))
        XCTAssertTrue(source.contains("MediaRuntimeReducer."))
    }

    func testMediaRestartPanicSafetyMovedIntoMediaReducer() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/MediaRuntimeReducer.swift"
        )
        let restartBody = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "restartCurrent"))

        XCTAssertTrue(restartBody.contains("state.panic.isActive"))
        XCTAssertTrue(restartBody.contains(".seekMediaToStart"))
    }

    func testMediaTogglePanicSafetyMovedIntoMediaReducer() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/MediaRuntimeReducer.swift"
        )
        let toggleBody = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "togglePlayback"))

        XCTAssertTrue(toggleBody.contains("state.panic.isActive"))
        XCTAssertTrue(toggleBody.contains(".panicChanged"))
    }
}
