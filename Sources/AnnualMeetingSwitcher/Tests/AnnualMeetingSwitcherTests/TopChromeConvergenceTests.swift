import XCTest
@testable import LiveSwitcher

final class TopChromeConvergenceTests: XCTestCase {
    func testMainConsoleTabsProvideDynamicChromeTitles() {
        XCTAssertEqual(MainConsoleTab.preview.chromeTitle, "LiveSwitcher · 导播台")
        XCTAssertEqual(MainConsoleTab.audioMixer.chromeTitle, "LiveSwitcher · 音频")
        XCTAssertEqual(MainConsoleTab.overlays.chromeTitle, "LiveSwitcher · 叠层")
    }

    func testContentViewNoLongerOwnsDuplicateLiveStatusStrip() throws {
        let source = try sourceText("ContentView.swift")

        XCTAssertFalse(source.contains("LiveStatusStrip("))
        XCTAssertFalse(source.contains("private struct LiveStatusStrip"))
        XCTAssertFalse(source.contains("Text(\"Run Desk\")"))
        XCTAssertTrue(source.contains("selectedMainTab.chromeTitle"))
    }

    func testProgramMonitorUsesCompactInlineStatusInsteadOfCurrentNextCards() throws {
        let source = try sourceText("Views/ProgramMonitorView.swift")

        XCTAssertFalse(source.contains("currentNextInfoRow"))
        XCTAssertFalse(source.contains("monitorInfoBlock"))
        XCTAssertTrue(source.contains("monitorInlineStatusRow"))
        XCTAssertTrue(source.contains("accessibilityLabel(monitorInlineAccessibilityLabel)"))
    }

    func testPreflightButtonValueIncludesBlockingCounts() {
        let fail = LivePreflightSummary(
            status: .fail,
            title: "Not ready",
            message: "",
            passCount: 4,
            warnCount: 2,
            failCount: 1
        )
        let warn = LivePreflightSummary(
            status: .warn,
            title: "Needs review",
            message: "",
            passCount: 4,
            warnCount: 2,
            failCount: 0
        )

        XCTAssertEqual(PreflightButtonModel.make(summary: fail).value, "1 错 · 2 警告")
        XCTAssertEqual(PreflightButtonModel.make(summary: warn).value, "2 警告")
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
