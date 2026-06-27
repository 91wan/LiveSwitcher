import XCTest

final class LeftPanelStaticTests: XCTestCase {
    func testLeftPanelDoesNotKeepUnreachableKeynoteImportHelpers() throws {
        let source = try String(contentsOf: leftPanelURL(), encoding: .utf8)

        XCTAssertFalse(source.contains("private func scanKeynoteWindows()"))
        XCTAssertFalse(source.contains("private func importKeynotePicker()"))
    }

    func testLeftPanelSourceListAvoidsTypeErasedViewsAndDeadNextProgramHelper() throws {
        let source = try String(contentsOf: programQueueListURL(), encoding: .utf8)

        XCTAssertFalse(source.contains("AnyView"))
        XCTAssertFalse(source.contains("private var nextProgramItem"))
        XCTAssertTrue(source.contains("struct ProgramQueueList: View"))
        XCTAssertTrue(source.contains("ProgramQueueStore.nextPlayableIndexAfterCurrent"))
    }

    func testPowerPointPickerAcceptsLegacyPPTFiles() throws {
        let source = try String(contentsOf: programImportDropZoneURL(), encoding: .utf8)

        XCTAssertTrue(source.contains("filenameExtension: \"ppt\""))
    }

    func testKeynotePickerAcceptsKeynotePackageFiles() throws {
        let source = try String(contentsOf: programImportDropZoneURL(), encoding: .utf8)

        XCTAssertTrue(source.contains("filenameExtension: \"keynote\""))
    }

    func testProgramSetupRailFilesStayFocusedAndOffComplexityAllowlist() throws {
        let focusedFiles = [
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/Setup/LeftPanel.swift",
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/Setup/ProgramRailHeader.swift",
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/Setup/ProgramRailControls.swift",
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/Setup/ProgramImportDropZone.swift",
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/Setup/ProgramQueueList.swift",
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/Setup/ProgramRailFooter.swift",
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/Setup/ProgramDropHandler.swift"
        ]

        for relativePath in focusedFiles {
            let url = try repositoryRoot().appendingPathComponent(relativePath)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Missing focused setup rail file: \(relativePath)")
            XCTAssertLessThan(try lineCount(in: url), 250, "\(relativePath) should stay below 250 lines")
        }

        let allowlist = try String(
            contentsOf: repositoryRoot().appendingPathComponent("docs/architecture/complexity-allowlist.tsv"),
            encoding: .utf8
        )
        XCTAssertFalse(allowlist.contains("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LeftPanel.swift"))
        XCTAssertFalse(allowlist.contains("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/Setup/LeftPanel.swift"))
    }

    private func leftPanelURL() throws -> URL {
        return try repositoryRoot()
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/Setup/LeftPanel.swift")
    }

    private func programImportDropZoneURL() throws -> URL {
        try repositoryRoot()
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/Setup/ProgramImportDropZone.swift")
    }

    private func programQueueListURL() throws -> URL {
        try repositoryRoot()
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/Setup/ProgramQueueList.swift")
    }

    private func lineCount(in url: URL) throws -> Int {
        try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .count
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
