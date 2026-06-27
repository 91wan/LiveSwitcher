import XCTest

final class PreflightTypographyConvergenceTests: XCTestCase {
    func testPreflightPopoverUsesStudioTypeScaleInsteadOfRawSystemFontLiterals() throws {
        let source = try [
            "Views/Support/PreflightPopoverView.swift",
            "Views/Support/PreflightSummaryHeader.swift",
            "Views/Support/PreflightCheckList.swift",
            "Views/Support/PreflightCheckRow.swift",
            "Views/Support/PreflightPermissionSection.swift",
            "Views/Support/PreflightSupportActions.swift"
        ].map(sourceText).joined(separator: "\n")

        XCTAssertFalse(source.contains(".font(.system(size:"))
        XCTAssertTrue(source.contains("StudioTheme.TypeScale"))
    }

    func testSafetyCockpitUsesStudioTypeScaleInsteadOfRawSystemFontLiterals() throws {
        let source = try [
            "Views/Support/SafetyCockpitView.swift",
            "Views/Support/SafetyCockpitHeader.swift",
            "Views/Support/SafetyCockpitStatusGrid.swift",
            "Views/Support/SafetyCockpitRiskRow.swift",
            "Views/Support/SafetyCockpitSupportActions.swift"
        ].map(sourceText).joined(separator: "\n")

        XCTAssertFalse(source.contains(".font(.system(size:"))
        XCTAssertTrue(source.contains("StudioTheme.TypeScale"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try LiveSwitcherTests.sourceText(relativePath, filePath: #filePath)
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
