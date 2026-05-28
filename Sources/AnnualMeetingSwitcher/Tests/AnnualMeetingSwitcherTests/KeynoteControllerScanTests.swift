import XCTest

final class KeynoteControllerScanTests: XCTestCase {
    func testOpenKeynoteScanAcceptsCaseInsensitiveDeckExtensionsAndLegacyPPT() throws {
        let source = try sourceText("Engines/KeynoteController.swift")

        XCTAssertTrue(source.contains("let normalizedPath = $0.lowercased()"))
        XCTAssertTrue(source.contains("normalizedPath.hasSuffix(\".key\")"))
        XCTAssertTrue(source.contains("normalizedPath.hasSuffix(\".pptx\")"))
        XCTAssertTrue(source.contains("normalizedPath.hasSuffix(\".ppt\")"))
        XCTAssertTrue(source.contains("normalizedPath.hasSuffix(\".keynote\")"))
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
