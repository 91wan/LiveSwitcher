import XCTest
@testable import LiveSwitcher

final class ProgramItemSourceCapabilitiesTests: XCTestCase {
    func testSupportsSeekingUsesSourceURLInsteadOfPersistedSubtitle() {
        let oldVideo = ProgramItem(
            title: "Restored video",
            subtitle: "VIDEO",
            sourceURL: URL(fileURLWithPath: "/tmp/restored.mp4")
        )
        let mp4 = ProgramItem(
            title: "MP4",
            subtitle: "MP4",
            sourceURL: URL(fileURLWithPath: "/tmp/current.mp4")
        )

        XCTAssertTrue(oldVideo.supportsSeeking)
        XCTAssertTrue(mp4.supportsSeeking)
    }

    func testNonMediaSourcesDoNotSupportSeeking() {
        XCTAssertFalse(ProgramItem(title: "HTML", subtitle: "HTML", sourceURL: URL(fileURLWithPath: "/tmp/index.html")).supportsSeeking)
        XCTAssertFalse(ProgramItem(title: "PPTX", subtitle: "PPTX", sourceURL: URL(fileURLWithPath: "/tmp/deck.pptx")).supportsSeeking)
        XCTAssertFalse(ProgramItem(title: "Deck", subtitle: "KEY (活动)", sourceURL: nil).supportsSeeking)
    }

    func testLegacyPPTUsesPresentationCapabilities() {
        let legacyPPT = ProgramItem(
            title: "Legacy PPT",
            subtitle: "PPT",
            sourceURL: URL(fileURLWithPath: "/tmp/legacy.ppt")
        )

        XCTAssertEqual(legacyPPT.sourceKind, .pptx)
        XCTAssertTrue(legacyPPT.supportsPresentationControl)
        XCTAssertFalse(legacyPPT.supportsSeeking)
        XCTAssertEqual(legacyPPT.displaySourceLabel, "PPTX")
    }

    func testDisplaySourceLabelUsesSourceKind() {
        XCTAssertEqual(ProgramItem(title: "Movie", subtitle: "VIDEO", sourceURL: URL(fileURLWithPath: "/tmp/movie.mp4")).displaySourceLabel, "VIDEO")
        XCTAssertEqual(ProgramItem(title: "HTML", subtitle: "HTML", sourceURL: URL(fileURLWithPath: "/tmp/index.html")).displaySourceLabel, "HTML")
        XCTAssertEqual(ProgramItem(title: "Deck", subtitle: "KEY (活动)", sourceURL: nil).displaySourceLabel, "DECK")
    }
}
