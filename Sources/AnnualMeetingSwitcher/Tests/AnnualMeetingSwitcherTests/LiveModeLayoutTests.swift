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
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.quickActionButtonHeight, 34)
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

    func testLiveSourcesEmptyStateOffersSetupCTA() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("Switch to Setup"))
        XCTAssertTrue(source.contains("viewModel.consoleMode = .setup"))
        XCTAssertTrue(source.contains("viewModel.selectedMainTab = .preview"))
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

    func testLiveBGMCardOffersLibraryPickerWithoutLeavingLiveMode() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("LiveBGMQuickPickerModel.make"))
        XCTAssertTrue(source.contains("Choose BGM from library"))
        XCTAssertTrue(source.contains("BGMCategory.allCases"))
        XCTAssertTrue(source.contains("viewModel.toggleBGM(item)"))
        XCTAssertTrue(source.contains("Open BGM Library"))
    }

    func testLiveWallpaperCardSelectsSpecificWallpaperInsteadOfCycling() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("LiveWallpaperQuickPickerModel.make"))
        XCTAssertTrue(source.contains("Choose standby wallpaper"))
        XCTAssertTrue(source.contains("viewModel.setActiveWallpaper(url: item.url)"))
        XCTAssertTrue(source.contains("ForEach(picker.items)"))
        XCTAssertFalse(source.contains("Next wallpaper"))
    }

    func testLiveLowerThirdPresetMenuSendsSelectedPresetDirectly() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("lowerThirdPresetMenu"))
        XCTAssertTrue(source.contains("ForEach(viewModel.lowerThirdPresets)"))
        XCTAssertTrue(source.contains("viewModel.showLowerThirdPreset(preset)"))
        XCTAssertTrue(source.contains("Choose lower third preset"))
    }

    func testLiveCountdownPresetMenuStartsSelectedPresetDirectly() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("countdownPresetMenu"))
        XCTAssertTrue(source.contains("ForEach(viewModel.countdownPresets)"))
        XCTAssertTrue(source.contains("viewModel.startCountdownPreset(preset)"))
        XCTAssertTrue(source.contains("Choose countdown preset"))
    }

    func testLiveTickerPresetMenuStartsSelectedPresetDirectly() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("tickerPresetMenu"))
        XCTAssertTrue(source.contains("ForEach(viewModel.tickerPresets)"))
        XCTAssertTrue(source.contains("viewModel.startTickerPreset(preset)"))
        XCTAssertTrue(source.contains("Choose ticker preset"))
    }

    func testLiveOverlayQuickActionsUseProtectedHitTargetHeight() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains(".frame(height: LiveModeLayoutMetrics.quickActionButtonHeight)"))
        XCTAssertFalse(source.contains(".frame(height: 30)"))
    }

    func testAudioAndOverlaySubtitlesUseEnglishCopy() throws {
        let audio = try sourceText("Views/AudioMixerView.swift")
        let overlays = try sourceText("Views/SettingsView.swift")

        XCTAssertTrue(audio.contains("Mixer faders, routing strategy, and BGM library"))
        XCTAssertTrue(overlays.contains("Compose on the left, preview on the right."))
        XCTAssertFalse(audio.contains("routing strategy 和 BGM library 分区管理"))
        XCTAssertFalse(overlays.contains("当前 live 状态"))
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
