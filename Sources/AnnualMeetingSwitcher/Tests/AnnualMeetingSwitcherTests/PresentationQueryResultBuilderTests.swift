import XCTest
@testable import LiveSwitcher

final class PresentationQueryResultBuilderTests: XCTestCase {
    func testBuildsProgramItemsFromPresentationQueryResult() {
        let items = PresentationQueryResultBuilder.makeProgramItems(
            from: PresentationQueryResult(
                openFilePaths: ["/tmp/show/Opening.key"],
                windowNames: ["Ignored.key"]
            ),
            existingProgramItems: []
        )

        XCTAssertEqual(items.map(\.title), ["Opening"])
    }

    func testPresentationQueryResultEmptyBuildsNoItems() {
        let items = PresentationQueryResultBuilder.makeProgramItems(
            from: .empty,
            existingProgramItems: []
        )

        XCTAssertTrue(items.isEmpty)
    }

    func testPresentationQueryResultIsEquatable() {
        XCTAssertEqual(
            PresentationQueryResult(openFilePaths: ["/tmp/Opening.key"], windowNames: ["Opening.key"]),
            PresentationQueryResult(openFilePaths: ["/tmp/Opening.key"], windowNames: ["Opening.key"])
        )
        XCTAssertNotEqual(
            PresentationQueryResult(openFilePaths: ["/tmp/Opening.key"], windowNames: ["Opening.key"]),
            PresentationQueryResult(openFilePaths: [], windowNames: ["Opening.key"])
        )
    }

    func testPresentationQueryResultBuilderDoesNotReferenceKeynoteController() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/PresentationQueryResultBuilder.swift"
        )

        XCTAssertFalse(source.contains("KeynoteController"))
    }

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
        let openingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Opening")
            .appendingPathExtension("key")
        let finaleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Finale")
            .appendingPathExtension("key")
        let existing = ProgramItem(title: "Opening", subtitle: "KEY", sourceURL: openingURL)

        let items = PresentationQueryResultBuilder.makeProgramItems(
            openFilePaths: [openingURL.path, finaleURL.path],
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

    func testCleansKeynoteWindowTitlesThroughPresentationWindowTitlePolicy() {
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
