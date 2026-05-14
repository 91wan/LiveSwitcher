import XCTest
@testable import LiveSwitcher

final class ProgramQueueStoreTests: XCTestCase {
    func testPersistentProgramItemsDropsSyntheticDeckItems() {
        let media = ProgramItem(title: "Video", sourceURL: URL(fileURLWithPath: "/tmp/video.mp4"))
        let activeDeck = ProgramItem(title: "Active deck", subtitle: "ACTIVE KEYNOTE DECK", sourceURL: nil)

        XCTAssertEqual(ProgramQueueStore.persistentProgramItems(from: [media, activeDeck]), [media])
    }

    func testRestoredProgramItemsSkipsMissingFilesAndKeepsTitlesAligned() {
        let restored = ProgramQueueStore.restoredProgramItems(
            paths: ["/tmp/one.mp4", "/tmp/missing.mov", "/tmp/three.html"],
            titles: ["One", "Missing", "Three"],
            subtitles: ["VIDEO", "VIDEO", "HTML"],
            fileExists: { $0 != "/tmp/missing.mov" }
        )

        XCTAssertEqual(restored.map(\.title), ["One", "Three"])
        XCTAssertEqual(restored.map(\.subtitle), ["VIDEO", "HTML"])
        XCTAssertEqual(restored.map { $0.sourceURL?.path }, ["/tmp/one.mp4", "/tmp/three.html"])
    }

    func testNextVideoAfterCurrentOnlyReturnsImmediateVideoNeighbor() {
        let first = ProgramItem(title: "First", sourceURL: URL(fileURLWithPath: "/tmp/first.mp4"))
        let nextVideo = ProgramItem(title: "Next", sourceURL: URL(fileURLWithPath: "/tmp/next.mov"))
        let html = ProgramItem(title: "HTML", sourceURL: URL(fileURLWithPath: "/tmp/index.html"))
        let thirdVideo = ProgramItem(title: "Third", sourceURL: URL(fileURLWithPath: "/tmp/third.mp4"))

        XCTAssertEqual(
            ProgramQueueStore.nextVideoAfterCurrent(current: first, in: [first, nextVideo, html]),
            nextVideo
        )
        XCTAssertNil(ProgramQueueStore.nextVideoAfterCurrent(current: nextVideo, in: [first, nextVideo, html, thirdVideo]))
        XCTAssertNil(ProgramQueueStore.nextVideoAfterCurrent(current: nil, in: [first, nextVideo]))
    }
}
