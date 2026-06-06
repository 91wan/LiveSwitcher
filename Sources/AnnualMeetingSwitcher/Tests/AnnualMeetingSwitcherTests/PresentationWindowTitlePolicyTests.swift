import XCTest
@testable import LiveSwitcher

final class PresentationWindowTitlePolicyTests: XCTestCase {
    func testCleansKeyExtension() {
        XCTAssertEqual(PresentationWindowTitlePolicy.cleanedDocumentTitle(from: "Annual Show.KEY"), "Annual Show")
    }

    func testCleansKeynoteExtension() {
        XCTAssertEqual(PresentationWindowTitlePolicy.cleanedDocumentTitle(from: "Awards.keynote"), "Awards")
    }

    func testCleansPPTXExtension() {
        XCTAssertEqual(PresentationWindowTitlePolicy.cleanedDocumentTitle(from: "Slides.pptx"), "Slides")
    }

    func testCleansPPTExtension() {
        XCTAssertEqual(PresentationWindowTitlePolicy.cleanedDocumentTitle(from: "Legacy Deck.PPT"), "Legacy Deck")
    }

    func testKeepsUnknownExtension() {
        XCTAssertEqual(PresentationWindowTitlePolicy.cleanedDocumentTitle(from: "Agenda.pdf"), "Agenda.pdf")
    }

    func testKeepsTitleWithoutExtension() {
        XCTAssertEqual(PresentationWindowTitlePolicy.cleanedDocumentTitle(from: "Window Without Extension"), "Window Without Extension")
    }

    func testKeynoteControllerCleanerMatchesPresentationWindowTitlePolicy() {
        for title in ["Annual Show.KEY", "Awards.keynote", "Slides.pptx", "Legacy Deck.PPT", "Agenda.pdf"] {
            XCTAssertEqual(
                KeynoteController.cleanedDocumentTitle(from: title),
                PresentationWindowTitlePolicy.cleanedDocumentTitle(from: title)
            )
        }
    }
}
