import XCTest
@testable import LiveSwitcher

final class LiveModeLayoutTests: XCTestCase {
    func testLiveModeLayoutMetricsProtectMonitorPriorityAndHitTargets() {
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.monitorHeightRatio, 0.50)
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.audioStripHeight, 110)
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.sourceRailWidth, 200)
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.quickRailWidth, 200)
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.footerHeight, 26)
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.transportButtonSize, 32)
    }

    func testLiveModeViewDefinesDedicatedStageFourRegions() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("struct LiveModeView"))
        XCTAssertTrue(source.contains("struct LiveSourceRail"))
        XCTAssertTrue(source.contains("struct LiveProgramStack"))
        XCTAssertTrue(source.contains("struct LiveAudioStrip"))
        XCTAssertTrue(source.contains("struct LiveQuickRail"))
        XCTAssertTrue(source.contains("struct LiveRuntimeStatusBar"))
    }

    func testContentViewRoutesLiveModeToDedicatedLayout() throws {
        let source = try sourceText("ContentView.swift")

        XCTAssertTrue(source.contains("LiveModeView"))
        XCTAssertTrue(source.contains("if viewModel.consoleMode == .live"))
        XCTAssertFalse(source.contains("runDesk(isLiveMode: viewModel.consoleMode == .live)"))
    }

    func testLiveModeDoesNotExposeSetupOnlyImportControls() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertFalse(source.contains("Add Source"))
        XCTAssertFalse(source.contains("Drag files here"))
        XCTAssertFalse(source.contains("Auto-next video"))
        XCTAssertFalse(source.contains("Import wallpaper"))
        XCTAssertFalse(source.contains("scanAndAddKeynoteWindows"))
    }

    func testProgramMonitorLiveModeHidesSetupUtilitiesAndHeightCap() throws {
        let source = try sourceText("Views/ProgramMonitorView.swift")

        XCTAssertTrue(source.contains("if !isLiveMode"))
        XCTAssertTrue(source.contains("livePreviewMaxHeight"))
        XCTAssertTrue(source.contains("isLiveMode ? .infinity : 342"))
    }

    func testLiveAudioStripExposesThreeFadersWithoutSwitchingTabs() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("$viewModel.masterVolume"))
        XCTAssertTrue(source.contains("$viewModel.mediaVolume"))
        XCTAssertTrue(source.contains("$viewModel.bgmVolume"))
        XCTAssertTrue(source.contains("Master"))
        XCTAssertTrue(source.contains("Media"))
        XCTAssertTrue(source.contains("BGM"))
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
