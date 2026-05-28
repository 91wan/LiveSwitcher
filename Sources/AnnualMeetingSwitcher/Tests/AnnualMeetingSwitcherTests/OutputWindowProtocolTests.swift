import XCTest
@testable import LiveSwitcher

final class OutputWindowProtocolTests: XCTestCase {
    func testOutputWindowProtocolDoesNotExposeUnusedFullScreenParameter() throws {
        let source = try sourceText("Output/OutputWindowController.swift")

        XCTAssertFalse(source.contains("fullScreen:"))
        XCTAssertTrue(source.contains("func show(on screen: NSScreen?)"))
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
