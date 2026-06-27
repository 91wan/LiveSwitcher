import XCTest

final class SectionCardBadgePolicyTests: XCTestCase {
    func testStudioSectionCardUsesStatusBadgeVisibilityPolicy() throws {
        let source = try sourceText("Views/Theme/StudioTheme+Components.swift")

        XCTAssertTrue(
            source.contains("StatusBadgeVisibilityPolicy.shouldShow(text: status.0, kind: status.1)"),
            "StudioSectionCard should hide default idle section statuses and show only exception badges."
        )
        XCTAssertFalse(source.contains("if let status {\n                        StatusBadge(status.0, kind: status.1)"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
