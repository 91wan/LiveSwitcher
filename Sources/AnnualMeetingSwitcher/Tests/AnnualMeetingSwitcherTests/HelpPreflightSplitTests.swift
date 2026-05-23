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
        XCTAssertTrue(try sourceFileExists("Views/PreflightPopoverView.swift"))
        let preflight = try sourceText("Views/PreflightPopoverView.swift")

        XCTAssertTrue(preflight.contains("struct PreflightPopoverView"))
        XCTAssertTrue(preflight.contains("PreflightListMode"))
        XCTAssertTrue(preflight.contains("Copy Support"))
        XCTAssertTrue(preflight.contains("Save Support"))
        XCTAssertFalse(preflight.contains("HelpCopyModel.sections"))
    }

    func testProgramMonitorMovedOutOfContentView() throws {
        let content = try sourceText("ContentView.swift")

        XCTAssertTrue(try sourceFileExists("Views/ProgramMonitorView.swift"))
        XCTAssertFalse(content.contains("struct ProgramMonitorView"))
        XCTAssertFalse(content.contains("struct WallpaperGalleryRow"))

        let monitor = try sourceText("Views/ProgramMonitorView.swift")
        XCTAssertTrue(monitor.contains("struct ProgramMonitorView"))
        XCTAssertTrue(monitor.contains("struct WallpaperGalleryRow"))
    }

    func testQueueRowMovedOutOfLeftPanel() throws {
        let leftPanel = try sourceText("Views/LeftPanel.swift")

        XCTAssertTrue(try sourceFileExists("Views/RunQueueView.swift"))
        XCTAssertFalse(leftPanel.contains("struct SignalSourceRow"))
        XCTAssertFalse(leftPanel.contains("struct ProgressSliderRow"))

        let queue = try sourceText("Views/RunQueueView.swift")
        XCTAssertTrue(queue.contains("struct SignalSourceRow"))
        XCTAssertTrue(queue.contains("struct ProgressSliderRow"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceFileExists(_ relativePath: String) throws -> Bool {
        FileManager.default.fileExists(atPath: try sourceURL(relativePath).path)
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
