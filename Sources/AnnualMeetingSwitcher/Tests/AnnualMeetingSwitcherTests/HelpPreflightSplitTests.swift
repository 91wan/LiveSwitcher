import XCTest

final class HelpPreflightSplitTests: XCTestCase {
    func testMainToolbarUsesDedicatedHelpAndPreflightPopovers() throws {
        let toolbar = try sourceText("Views/MainToolbar.swift")

        XCTAssertTrue(toolbar.contains("HelpPopoverView("))
        XCTAssertTrue(toolbar.contains("PreflightPopoverView("))
        XCTAssertFalse(toolbar.contains("HelpView(initialPanel: .help"))
        XCTAssertFalse(toolbar.contains("HelpView(initialPanel: .preflight"))
        XCTAssertFalse(toolbar.contains("enum HelpPanel"))
    }

    func testHelpPopoverDoesNotOwnPreflightActions() throws {
        XCTAssertTrue(try sourceFileExists("Views/HelpPopoverView.swift"))
        let help = try sourceText("Views/HelpPopoverView.swift")

        XCTAssertTrue(help.contains("struct HelpPopoverView"))
        XCTAssertTrue(help.contains("HelpCopyModel.sections"))
        XCTAssertFalse(help.contains("PreflightListMode"))
        XCTAssertFalse(help.contains("Copy Support"))
        XCTAssertFalse(help.contains("Save Support"))
        XCTAssertFalse(help.contains("Open Cockpit"))
    }

    func testPreflightPopoverDoesNotOwnHelpCopy() throws {
        XCTAssertTrue(try sourceFileExists("Views/Support/PreflightPopoverView.swift"))
        let preflight = try sourceText("Views/PreflightPopoverView.swift")

        XCTAssertTrue(preflight.contains("struct PreflightPopoverView"))
        XCTAssertTrue(preflight.contains("PreflightReviewMode"))
        XCTAssertTrue(preflight.contains("PreflightReviewModel.make"))
        XCTAssertTrue(preflight.contains("复制支持报告"))
        XCTAssertTrue(preflight.contains("保存支持报告"))
        XCTAssertFalse(preflight.contains("HelpCopyModel.sections"))
    }

    func testPreflightPopoverFilesStayFocusedAndOffComplexityAllowlist() throws {
        let expectedFiles = [
            "Views/Support/PreflightPopoverView.swift",
            "Views/Support/PreflightSummaryHeader.swift",
            "Views/Support/PreflightCheckList.swift",
            "Views/Support/PreflightCheckRow.swift",
            "Views/Support/PreflightPermissionSection.swift",
            "Views/Support/PreflightSupportActions.swift"
        ]

        for relativePath in expectedFiles {
            XCTAssertTrue(try sourceFileExists(relativePath), "\(relativePath) should exist after the split.")
            let lineCount = try sourceText(relativePath).split(separator: "\n", omittingEmptySubsequences: false).count
            XCTAssertLessThan(lineCount, 250, "\(relativePath) should stay below the per-file complexity budget.")
        }

        let allowlist = try String(
            contentsOf: repositoryRoot(filePath: #filePath).appendingPathComponent("docs/architecture/complexity-allowlist.tsv"),
            encoding: .utf8
        )
        XCTAssertFalse(allowlist.contains("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/PreflightPopoverView.swift"))
        XCTAssertFalse(allowlist.contains("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/Support/PreflightPopoverView.swift"))
    }

    func testProgramMonitorMovedOutOfContentView() throws {
        let content = try sourceText("ContentView.swift")

        XCTAssertTrue(try sourceFileExists("Views/ProgramMonitor/ProgramMonitorView.swift"))
        XCTAssertFalse(content.contains("struct ProgramMonitorView"))
        XCTAssertFalse(content.contains("struct WallpaperGalleryRow"))

        let monitor = try sourceText("Views/ProgramMonitor/ProgramMonitorView.swift")
        XCTAssertTrue(monitor.contains("struct ProgramMonitorView"))
        XCTAssertFalse(monitor.contains("struct WallpaperGalleryRow"))
        XCTAssertFalse(monitor.contains("struct WallpaperThumbView"))
        XCTAssertFalse(monitor.contains("NSOpenPanel"))
        XCTAssertFalse(monitor.contains("persistDroppedWallpaperFile"))

        let wallpaper = try sourceText("Views/WallpaperGalleryRow.swift")
        XCTAssertTrue(wallpaper.contains("struct WallpaperGalleryRow"))
        XCTAssertTrue(wallpaper.contains("struct WallpaperThumbView"))
    }

    func testQueueRowMovedOutOfLeftPanel() throws {
        let leftPanel = try sourceText("Views/LeftPanel.swift")

        XCTAssertTrue(try sourceFileExists("Views/ProgramQueue/SignalSourceRow.swift"))
        XCTAssertTrue(try sourceFileExists("Views/ProgramQueue/ProgressSliderRow.swift"))
        XCTAssertFalse(leftPanel.contains("struct SignalSourceRow"))
        XCTAssertFalse(leftPanel.contains("struct ProgressSliderRow"))

        let queue = try sourceText("Views/ProgramQueue/SignalSourceRow.swift")
        let progress = try sourceText("Views/ProgramQueue/ProgressSliderRow.swift")
        XCTAssertTrue(queue.contains("struct SignalSourceRow"))
        XCTAssertTrue(progress.contains("struct ProgressSliderRow"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try LiveSwitcherTests.sourceText(relativePath, filePath: #filePath)
    }

    private func sourceFileExists(_ relativePath: String) throws -> Bool {
        return FileManager.default.fileExists(atPath: try sourceURL(relativePath).path)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        try sourceRoot().appendingPathComponent(relativePath)
    }

    private func sourceRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate AnnualMeetingSwitcher source root from test source path.")
    }
}
