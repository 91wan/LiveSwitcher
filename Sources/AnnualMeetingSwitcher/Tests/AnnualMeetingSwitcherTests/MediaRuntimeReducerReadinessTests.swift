import XCTest
@testable import LiveSwitcher

final class MediaRuntimeReducerReadinessTests: XCTestCase {
    func testNoMediaRuntimeReducerYet() throws {
        let root = try repositoryRoot()
        let path = root.appendingPathComponent(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/MediaRuntimeReducer.swift"
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: path.path))
    }

    func testMediaReducerExtractionRemainsFutureWork() throws {
        let docs = try repositorySource("docs/architecture/runtime-ownership.md")

        XCTAssertTrue(docs.contains("MediaRuntimeReducer"))
        XCTAssertTrue(docs.localizedStandardContains("future work"))
    }

    func testLiveRuntimeReducerStillOwnsMediaMutationForNow() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift"
        )

        XCTAssertTrue(source.contains("case .operatorRestartedCurrentMedia"))
        XCTAssertTrue(source.contains("guard isRuntimeOwned(.media"))
        XCTAssertFalse(source.contains("MediaRuntimeReducer."))
    }

    func testMediaRestartPanicSafetyIsFixedBeforeExtraction() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift"
        )
        let restartBody = try XCTUnwrap(
            source.slice(
                from: "case .operatorRestartedCurrentMedia:",
                to: "case .operatorSeekedCurrentMediaToStart:"
            )
        )

        XCTAssertTrue(restartBody.contains("state.panic.isActive"))
        XCTAssertTrue(restartBody.contains(".seekMediaToStart"))
    }

    func testMediaTogglePanicSafetyIsFixedBeforeExtraction() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift"
        )
        let toggleBody = try XCTUnwrap(
            source.slice(
                from: "case .operatorToggledMediaPlayback:",
                to: "case .operatorRestartedCurrentMedia:"
            )
        )

        XCTAssertTrue(toggleBody.contains("state.panic.isActive"))
        XCTAssertTrue(toggleBody.contains(".panicChanged"))
    }
}
