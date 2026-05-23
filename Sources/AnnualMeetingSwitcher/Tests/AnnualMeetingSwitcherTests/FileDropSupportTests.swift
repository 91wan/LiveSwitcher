import XCTest
@testable import LiveSwitcher

final class FileDropSupportTests: XCTestCase {
    func testDecodeFileURLSupportsURLDataAndPlainStringPath() {
        let url = URL(fileURLWithPath: "/tmp/live-switcher/Opening Clip.mp4")

        XCTAssertEqual(FileDropSupport.decodeFileURL(from: url), url)
        XCTAssertEqual(FileDropSupport.decodeFileURL(from: url.dataRepresentation), url)
        XCTAssertEqual(FileDropSupport.decodeFileURL(from: "file:///tmp/live-switcher/Opening%20Clip.mp4"), url)
        XCTAssertEqual(FileDropSupport.decodeFileURL(from: "/tmp/live-switcher/Opening Clip.mp4"), url)
    }

    func testDecodeFileURLSupportsTildePathString() {
        let decoded = FileDropSupport.decodeFileURL(from: "~/LiveSwitcherTest/Opening.mp4")

        XCTAssertEqual(
            decoded,
            URL(fileURLWithPath: NSString(string: "~/LiveSwitcherTest/Opening.mp4").expandingTildeInPath)
        )
        XCTAssertTrue(decoded?.isFileURL == true)
    }

    func testDecodeFileURLRejectsUnsupportedString() {
        XCTAssertNil(FileDropSupport.decodeFileURL(from: "not a file path"))
        XCTAssertNil(FileDropSupport.decodeFileURL(from: "https://example.com/show.html"))
    }

    func testImportableProgramItemRecognizesSupportedSourceKinds() {
        let media = FileDropSupport.importableProgramItem(from: URL(fileURLWithPath: "/tmp/clip.mp4"))
        let html = FileDropSupport.importableProgramItem(from: URL(fileURLWithPath: "/tmp/index.html"))
        let pptx = FileDropSupport.importableProgramItem(from: URL(fileURLWithPath: "/tmp/deck.pptx"))
        let keynote = FileDropSupport.importableProgramItem(from: URL(fileURLWithPath: "/tmp/deck.key"))

        XCTAssertEqual(media?.sourceKind, .media)
        XCTAssertEqual(html?.sourceKind, .html)
        XCTAssertEqual(pptx?.sourceKind, .pptx)
        XCTAssertEqual(keynote?.sourceKind, .keynote)
    }

    func testImportableProgramItemRejectsUnsupportedFiles() {
        XCTAssertNil(FileDropSupport.importableProgramItem(from: URL(fileURLWithPath: "/tmp/notes.txt")))
    }
}
