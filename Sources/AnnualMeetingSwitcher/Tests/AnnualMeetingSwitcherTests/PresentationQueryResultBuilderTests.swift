import XCTest
@testable import LiveSwitcher

final class PresentationQueryResultBuilderTests: XCTestCase {
    func testBuildsProgramItemsFromOpenFilePaths() {
        let items = PresentationQueryResultBuilder.makeProgramItems(
            openFilePaths: ["/tmp/show/Opening.key", "/tmp/show/Finale.pptx"],
            windowNames: [],
            existingProgramItems: []
        )

        XCTAssertEqual(items.map(\.title), ["Opening", "Finale"])
        XCTAssertEqual(items.map(\.subtitle), ["KEY", "KEY"])
        XCTAssertEqual(items.map(\.sourceURL?.path), ["/tmp/show/Opening.key", "/tmp/show/Finale.pptx"])
    }

    func testFilePathResultsWinOverWindowNameResults() {
        let items = PresentationQueryResultBuilder.makeProgramItems(
            openFilePaths: ["/tmp/show/Opening.key"],
            windowNames: ["Ignored.key"],
            existingProgramItems: []
        )

        XCTAssertEqual(items.map(\.title), ["Opening"])
    }

    func testDedupesOpenFilePathsAgainstExistingProgramItems() {
        let existing = ProgramItem(title: "Opening", subtitle: "KEY", sourceURL: URL(fileURLWithPath: "/tmp/show/Opening.key"))

        let items = PresentationQueryResultBuilder.makeProgramItems(
            openFilePaths: ["/tmp/show/Opening.key", "/tmp/show/Finale.key"],
            windowNames: [],
            existingProgramItems: [existing]
        )

        XCTAssertEqual(items.map(\.title), ["Finale"])
    }

    func testDedupesOpenFilePathsWithinQueryResult() {
        let items = PresentationQueryResultBuilder.makeProgramItems(
            openFilePaths: ["/tmp/show/Opening.key", "/tmp/show/Opening.key"],
            windowNames: [],
            existingProgramItems: []
        )

        XCTAssertEqual(items.map(\.title), ["Opening"])
    }

    func testBuildsActiveDeckItemsFromWindowNamesWhenNoFilePaths() {
        let items = PresentationQueryResultBuilder.makeProgramItems(
            openFilePaths: [],
            windowNames: ["Opening.key", "Finale.pptx"],
            existingProgramItems: []
        )

        XCTAssertEqual(items.map(\.title), ["Opening", "Finale"])
        XCTAssertEqual(items.map(\.subtitle), ["KEY (活动)", "KEY (活动)"])
        XCTAssertEqual(items.map(\.sourceURL), [nil, nil])
    }

    func testCleansKeynoteWindowTitles() {
        let items = PresentationQueryResultBuilder.makeProgramItems(
            openFilePaths: [],
            windowNames: ["Annual Show.KEY", "Legacy Deck.PPT"],
            existingProgramItems: []
        )

        XCTAssertEqual(items.map(\.title), ["Annual Show", "Legacy Deck"])
    }

    func testDedupesWindowNamesAgainstExistingProgramItems() {
        let existing = ProgramItem(title: "Opening", subtitle: "KEY (活动)", sourceURL: nil)

        let items = PresentationQueryResultBuilder.makeProgramItems(
            openFilePaths: [],
            windowNames: ["Opening.key", "Finale.pptx"],
            existingProgramItems: [existing]
        )

        XCTAssertEqual(items.map(\.title), ["Finale"])
    }

    func testDedupesWindowNamesWithinQueryResult() {
        let items = PresentationQueryResultBuilder.makeProgramItems(
            openFilePaths: [],
            windowNames: ["Opening.key", "Opening.pptx"],
            existingProgramItems: []
        )

        XCTAssertEqual(items.map(\.title), ["Opening"])
    }

    func testReturnsEmptyWhenNoResults() {
        let items = PresentationQueryResultBuilder.makeProgramItems(
            openFilePaths: [],
            windowNames: [],
            existingProgramItems: []
        )

        XCTAssertTrue(items.isEmpty)
    }
}
