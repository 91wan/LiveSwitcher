import XCTest

final class LeftPanelStaticTests: XCTestCase {
    func testLeftPanelDoesNotKeepUnreachableKeynoteImportHelpers() throws {
        let source = try String(contentsOf: leftPanelURL(), encoding: .utf8)

        XCTAssertFalse(source.contains("private func scanKeynoteWindows()"))
        XCTAssertFalse(source.contains("private func importKeynotePicker()"))
    }

    func testLeftPanelSourceListAvoidsTypeErasedViewsAndDeadNextProgramHelper() throws {
        let source = try String(contentsOf: leftPanelURL(), encoding: .utf8)

        XCTAssertFalse(source.contains("AnyView"))
        XCTAssertFalse(source.contains("private var nextProgramItem"))
        XCTAssertTrue(source.contains("@ViewBuilder"))
        XCTAssertTrue(source.contains("private var sourceList: some View"))
    }

    private func leftPanelURL() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LeftPanel.swift")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate LeftPanel.swift from test source path.")
    }
}
