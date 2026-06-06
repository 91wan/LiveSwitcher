import Foundation
import XCTest
@testable import LiveSwitcher

final class PresentationQueryResultBuilderTests: XCTestCase {
    func testFileBackedItemsDedupeExistingSourceURL() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Opening")
            .appendingPathExtension("key")
        let existingItems = [ProgramItem(
            title: "Opening",
            subtitle: "KEY",
            sourceURL: url
        )]

        let itemsToAdd = PresentationQueryResultBuilder.makeProgramItems(
            openFilePaths: [url.path],
            windowNames: [],
            existingProgramItems: existingItems
        )

        XCTAssertTrue(itemsToAdd.isEmpty)
    }

    func testActiveDeckItemsDedupeExistingWindowTitle() {
        let existingItems = [
            ProgramItem(title: "Opening", subtitle: "KEY (活动)", sourceURL: nil)
        ]

        let itemsToAdd = PresentationQueryResultBuilder.makeProgramItems(
            openFilePaths: [],
            windowNames: ["Opening.key"],
            existingProgramItems: existingItems
        )

        XCTAssertTrue(itemsToAdd.isEmpty)
    }
}
