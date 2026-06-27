import XCTest

final class RunDeskInformationHierarchyTests: XCTestCase {
    func testRunDeskDoesNotReuseHeavyRightRailPanels() throws {
        let runDesk = try String(contentsOf: sourceURL("Views/AppShell/RunDeskLayout.swift"), encoding: .utf8)

        XCTAssertTrue(runDesk.contains("LiveOpsPanel"))
        XCTAssertFalse(runDesk.contains("BGMPlaylistPanel(mode: .liveDock)"))
        XCTAssertFalse(runDesk.contains("RightPanel(mode: .liveQuick"))
    }

    func testProgramMonitorDoesNotKeepDuplicatedProgramBus() throws {
        let runDesk = try String(contentsOf: sourceURL("Views/AppShell/RunDeskLayout.swift"), encoding: .utf8)

        XCTAssertFalse(runDesk.contains("programPresetRow"))
        XCTAssertFalse(runDesk.contains("节目总线"))
    }

    func testQueueRailNoLongerOwnsProjectionControls() throws {
        let leftPanel = try LiveSwitcherTests.sourceText("Views/Setup/LeftPanel.swift", filePath: #filePath)

        XCTAssertFalse(leftPanel.contains("outputScreenModule"))
        XCTAssertFalse(leftPanel.contains("Start Projection"))
        XCTAssertFalse(leftPanel.contains("External Display Required"))
    }

    func testRunNavigationUsesRunAudioOverlaysLanguage() throws {
        let modeCluster = try String(contentsOf: sourceURL("Views/AppShell/ConsoleModeCluster.swift"), encoding: .utf8)
        let tabs = try String(contentsOf: sourceURL("Models/MainConsoleTab.swift"), encoding: .utf8)

        XCTAssertTrue(modeCluster.contains("setupModeMenuButton"))
        XCTAssertTrue(tabs.contains("节目单"))
        XCTAssertTrue(tabs.contains("音频"))
        XCTAssertTrue(tabs.contains("叠层"))
        XCTAssertFalse(modeCluster.contains("预览 / 切换"))
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
