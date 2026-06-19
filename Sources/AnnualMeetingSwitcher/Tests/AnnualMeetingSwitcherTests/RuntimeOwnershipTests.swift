import XCTest
@testable import LiveSwitcher

final class RuntimeOwnershipTests: XCTestCase {
    func testRuntimeOwnershipDocumentExists() throws {
        XCTAssertTrue(FileManager.default.fileExists(atPath: try documentURL("runtime-ownership.md").path))
    }

    func testRuntimeOwnershipDocumentHasRequiredSections() throws {
        let document = try documentText("runtime-ownership.md")

        [
            "# Live Runtime Ownership",
            "## Production configuration",
            "## Ownership matrix",
            "## Boundary invariants",
            "## ViewModel-owned responsibilities",
            "## Architecture freeze"
        ].forEach { section in
            XCTAssertTrue(document.contains(section), "Missing section: \(section)")
        }
    }

    func testRuntimeOwnershipDocumentStaysWithinLineBudget() throws {
        XCTAssertLessThanOrEqual(try lineCount("runtime-ownership.md"), 170)
    }

    func testLiveModeSimplicityDocumentHasRequiredSections() throws {
        let document = try documentText("live-mode-simplicity-rules.md")

        [
            "# Live Mode Simplicity Rules",
            "## Product boundary",
            "## Allowed live actions",
            "## Forbidden live configuration",
            "## Runtime/UI separation rules",
            "## Architecture freeze"
        ].forEach { section in
            XCTAssertTrue(document.contains(section), "Missing section: \(section)")
        }
    }

    func testLiveModeSimplicityDocumentStaysWithinLineBudget() throws {
        XCTAssertLessThanOrEqual(try lineCount("live-mode-simplicity-rules.md"), 65)
    }

    private func documentText(_ fileName: String) throws -> String {
        try String(contentsOf: documentURL(fileName), encoding: .utf8)
    }

    private func lineCount(_ fileName: String) throws -> Int {
        try documentText(fileName).split(separator: "\n", omittingEmptySubsequences: false).count
    }

    private func documentURL(_ fileName: String) throws -> URL {
        try repositoryRoot()
            .appendingPathComponent("docs/architecture")
            .appendingPathComponent(fileName)
    }

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory.appendingPathComponent("docs")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return directory
            }
        }
        throw XCTSkip("Could not locate repository root from test source path.")
    }
}
