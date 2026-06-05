import XCTest
@testable import LiveSwitcher

final class KeynoteControllerScanTests: XCTestCase {
    func testOpenKeynoteScanAcceptsCaseInsensitiveDeckExtensionsAndLegacyPPT() throws {
        let source = try sourceText("Engines/KeynoteController.swift")

        XCTAssertTrue(source.contains("let normalizedPath = $0.lowercased()"))
        XCTAssertTrue(source.contains("normalizedPath.hasSuffix(\".key\")"))
        XCTAssertTrue(source.contains("normalizedPath.hasSuffix(\".pptx\")"))
        XCTAssertTrue(source.contains("normalizedPath.hasSuffix(\".ppt\")"))
        XCTAssertTrue(source.contains("normalizedPath.hasSuffix(\".keynote\")"))
    }

    func testCleanedDocumentTitleRemovesKnownPresentationExtensionsCaseInsensitively() {
        XCTAssertEqual(KeynoteController.cleanedDocumentTitle(from: "Annual Show.KEY"), "Annual Show")
        XCTAssertEqual(KeynoteController.cleanedDocumentTitle(from: "Awards.keynote"), "Awards")
        XCTAssertEqual(KeynoteController.cleanedDocumentTitle(from: "Legacy Deck.PPT"), "Legacy Deck")
        XCTAssertEqual(KeynoteController.cleanedDocumentTitle(from: "Slides.pptx"), "Slides")
        XCTAssertEqual(KeynoteController.cleanedDocumentTitle(from: "Window Without Extension"), "Window Without Extension")
    }

    func testViewModelUsesKeynoteTitleCleanerForActiveWindowImports() throws {
        let source = try sourceText("ViewModel+PresentationAutomation.swift")
        let body = try XCTUnwrap(source.functionBody(named: "scanAndAddKeynoteWindows"))

        XCTAssertTrue(body.contains("KeynoteController.cleanedDocumentTitle(from: name)"))
        XCTAssertFalse(body.contains("replacingOccurrences(of: \".key\""))
        XCTAssertFalse(body.contains("replacingOccurrences(of: \".pptx\""))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try String(contentsOf: candidate, encoding: .utf8)
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}

private extension String {
    func functionBody(named functionName: String) -> String? {
        let marker = "func \(functionName)"
        guard let markerRange = range(of: marker),
              let openingBrace = self[markerRange.lowerBound...].firstIndex(of: "{") else { return nil }

        var depth = 0
        var index = openingBrace
        while index < endIndex {
            let character = self[index]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(self[openingBrace...index])
                }
            }
            index = self.index(after: index)
        }
        return nil
    }
}
