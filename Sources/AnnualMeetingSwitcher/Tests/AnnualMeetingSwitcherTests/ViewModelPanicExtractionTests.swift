import XCTest
@testable import LiveSwitcher

final class ViewModelPanicExtractionTests: XCTestCase {
    func testPanicPlaybackSnapshotIsNotDeclaredInViewModelPanicFile() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Panic.swift")

        XCTAssertFalse(source.contains("struct PanicPlaybackSnapshot"))
    }

    func testPanicPlaybackSnapshotLivesInModels() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/PanicPlaybackSnapshot.swift")

        XCTAssertTrue(source.contains("struct PanicPlaybackSnapshot"))
    }

    func testPanicPlaybackSnapshotFieldsAreUnchanged() {
        let snapshot = PanicPlaybackSnapshot(
            currentProgramID: UUID(),
            wasMediaPlaying: true,
            currentBGMID: UUID(),
            wasBGMPlaying: true
        )

        XCTAssertNotNil(snapshot.currentProgramID)
        XCTAssertTrue(snapshot.wasMediaPlaying)
        XCTAssertNotNil(snapshot.currentBGMID)
        XCTAssertTrue(snapshot.wasBGMPlaying)
    }
}
