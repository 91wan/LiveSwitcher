import XCTest
@testable import LiveSwitcher

final class LiveModeLayoutTests: XCTestCase {
    func testLiveModeLayoutMetricsProtectMonitorPriorityAndHitTargets() {
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.monitorHeightRatio, 0.50)
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.audioStripHeight, 110)
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.sourceRailWidth, 200)
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.sourceRailWidthEmpty, 80)
        XCTAssertLessThanOrEqual(LiveModeLayoutMetrics.sourceRailWidthEmpty, 120)
        XCTAssertLessThan(LiveModeLayoutMetrics.sourceRailWidthEmpty, LiveModeLayoutMetrics.sourceRailWidth)
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.quickRailWidth, 200)
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.footerHeight, 26)
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.transportButtonSize, 32)
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.quickActionButtonHeight, 34)
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.contentTopPadding, 14)
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.contentBottomPadding, 6)
        XCTAssertGreaterThanOrEqual(ConsoleChromeLayoutMetrics.navigationBarMinHeight, 76)
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

    func testLiveSourceRailUsesUnifiedLabelModel() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("SourceRailRowLabelModel.make"))
        XCTAssertFalse(source.contains("Text(rowModel.queueBadgeText)"))
        XCTAssertFalse(source.contains("Text(item.displaySourceLabel)"))
    }

    func testLiveModePreservesBreathingRoomBelowChrome() throws {
        let source = try sourceText("Views/LiveModeView.swift")
        let content = try sourceText("ContentView.swift")

        XCTAssertTrue(source.contains(".padding(.top, LiveModeLayoutMetrics.contentTopPadding)"))
        XCTAssertFalse(source.contains(".padding(.top, 8)"))
        XCTAssertTrue(content.contains("ConsoleChromeLayoutMetrics.navigationBarMinHeight"))
        XCTAssertFalse(content.contains(".frame(minHeight: 64)"))
    }

    func testLiveQuickRailScrollsInsteadOfClippingDenseControls() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("ScrollView(.vertical, showsIndicators: false)"))
        XCTAssertFalse(source.contains(".scrollClipDisabled()"))
    }

    func testContentViewRoutesLiveModeToDedicatedLayout() throws {
        let source = try sourceText("ContentView.swift")

        XCTAssertTrue(source.contains("LiveModeView"))
        XCTAssertTrue(source.contains("liveContent"))
        XCTAssertTrue(source.contains("activeConsoleLayer(isActive: viewModel.consoleMode == .live)"))
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

        XCTAssertTrue(source.contains("切到准备模式"))
        XCTAssertTrue(source.contains("viewModel.navigateToSetup(.preview)"))
    }

    func testLiveSourceRailUsesAdaptiveEmptyWidthAndCompactEmptyCTA() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("LiveModeLayoutMetrics.sourceRailWidthEmpty"))
        XCTAssertTrue(source.contains("viewModel.programItems.isEmpty ? LiveModeLayoutMetrics.sourceRailWidthEmpty : LiveModeLayoutMetrics.sourceRailWidth"))
        XCTAssertTrue(source.contains(".animation(.easeInOut(duration: 0.2), value: viewModel.programItems.isEmpty)"))
        XCTAssertFalse(source.contains("EmptyStateView(\n                        title: \"No sources\""))
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
        XCTAssertTrue(source.contains("LiveBGMPlaylistModel.make"))
        XCTAssertTrue(source.contains("选择 BGM 分类"))
        XCTAssertTrue(source.contains("BGMCategory.allCases"))
        XCTAssertTrue(source.contains("viewModel.toggleBGM(row.item)"))
        XCTAssertTrue(source.contains("playlist.categoryButtonTitle"))
        XCTAssertTrue(source.contains("LiveBGMChooserPopover"))
        XCTAssertTrue(source.contains("全部曲目"))
        let legacyLibraryLabel = "Open BGM " + "Library"
        XCTAssertFalse(source.contains(legacyLibraryLabel))
        XCTAssertFalse(source.contains("onOpenMixer()"))
    }

    func testLiveModeQuickRailLeavesModesToTopToolbarAndKeepsCoreActions() throws {
        let liveMode = try sourceText("Views/LiveModeView.swift")
        let toolbar = try sourceText("Views/MainToolbar.swift")

        XCTAssertFalse(liveMode.contains("modesCard"))
        XCTAssertFalse(liveMode.contains("ModeToggleCard("))
        XCTAssertFalse(liveMode.contains("isOn: $viewModel.isSpeakerMode"))
        XCTAssertTrue(toolbar.contains("toolbarModeButtons"))
        XCTAssertTrue(toolbar.contains("toggleSpeakerMode()"))
        XCTAssertTrue(toolbar.contains("viewModel.togglePPTMode(source: pptModeToggleSource)"))
        XCTAssertFalse(toolbar.contains("viewModel.isPageInterceptEnabled.toggle()"))
        XCTAssertTrue(toolbar.contains("主持人"))
        XCTAssertTrue(toolbar.contains("PPT"))
    }

    func testLiveBGMCardShowsMiniPlaylistWithoutSetupNavigation() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("liveBGMCategory"))
        XCTAssertTrue(source.contains("liveBGMPlaylistRows("))
        XCTAssertTrue(source.contains("playlist.rows"))
        XCTAssertTrue(source.contains("playlist.remainingCountText"))
        XCTAssertTrue(source.contains("LiveBGMChooserPopover"))
        let legacyLibraryLabel = "Label(\"Open BGM " + "Library\""
        XCTAssertFalse(source.contains(legacyLibraryLabel))
    }

    func testLiveBGMTransportHasRestartButtonAndChineseTooltips() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("viewModel.seekBGMToBeginning()"))
        XCTAssertTrue(source.contains("\"跳回开头\""))
        XCTAssertTrue(source.contains("\"上一首\""))
        XCTAssertTrue(source.contains("\"播放 BGM\""))
        XCTAssertTrue(source.contains("\"暂停 BGM\""))
        XCTAssertTrue(source.contains("\"下一首\""))
        XCTAssertFalse(source.contains("\"BGM transport\""))
    }

    func testLiveQuickRailKeepsBGMPlaylistInFirstViewportPriority() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        guard let cut = source.range(of: "cutBusCard"),
              let bgm = source.range(of: "bgmCard"),
              let overlay = source.range(of: "overlayCard"),
              let wallpaper = source.range(of: "wallpaperCard") else {
            return XCTFail("Expected live quick rail cards to be declared in LiveModeView.")
        }

        XCTAssertLessThan(cut.lowerBound, bgm.lowerBound)
        XCTAssertLessThan(bgm.lowerBound, wallpaper.lowerBound)
        XCTAssertLessThan(wallpaper.lowerBound, overlay.lowerBound)
    }

    func testLiveWallpaperCardSelectsSpecificWallpaperInsteadOfCycling() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("LiveWallpaperQuickPickerModel.make"))
        XCTAssertTrue(source.contains("选择待机壁纸"))
        XCTAssertTrue(source.contains("viewModel.setActiveWallpaper(url: item.url)"))
        XCTAssertTrue(source.contains("ForEach(picker.items)"))
        XCTAssertFalse(source.contains("Next wallpaper"))
    }

    func testLiveLowerThirdPresetMenuSendsSelectedPresetDirectly() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("LiveOverlayRailRowModel.lowerThird"))
        XCTAssertTrue(source.contains("ForEach(viewModel.lowerThirdPresets)"))
        XCTAssertTrue(source.contains("viewModel.loadLowerThirdPreset(preset)"))
        XCTAssertTrue(source.contains("viewModel.showLowerThirdPreset(preset)"))
    }

    func testLiveCountdownPresetMenuStartsSelectedPresetDirectly() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("LiveOverlayRailRowModel.countdown"))
        XCTAssertTrue(source.contains("ForEach(viewModel.countdownPresets)"))
        XCTAssertTrue(source.contains("viewModel.loadCountdownPreset(preset)"))
        XCTAssertTrue(source.contains("viewModel.startCountdownPreset(preset)"))
    }

    func testLiveTickerPresetMenuStartsSelectedPresetDirectly() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("LiveOverlayRailRowModel.ticker"))
        XCTAssertTrue(source.contains("ForEach(viewModel.tickerPresets)"))
        XCTAssertTrue(source.contains("viewModel.loadTickerPreset(preset)"))
        XCTAssertTrue(source.contains("viewModel.startTickerPreset(preset)"))
    }

    func testLiveOverlayRailUsesCompactPresetRows() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("compactOverlayRow("))
        XCTAssertTrue(source.contains("LiveOverlayRailRowModel.lowerThird"))
        XCTAssertTrue(source.contains("LiveOverlayRailRowModel.countdown"))
        XCTAssertTrue(source.contains("LiveOverlayRailRowModel.ticker"))
        XCTAssertTrue(source.contains("overlayPresetMenu("))
        XCTAssertFalse(source.contains("private var lowerThirdPresetMenu"))
        XCTAssertFalse(source.contains("private var countdownPresetMenu"))
        XCTAssertFalse(source.contains("private var tickerPresetMenu"))
        XCTAssertFalse(source.contains("Choose lower third preset"))
        XCTAssertTrue(source.contains("viewModel.showLowerThirdPreset(preset)"))
        XCTAssertTrue(source.contains("viewModel.startCountdownPreset(preset)"))
        XCTAssertTrue(source.contains("viewModel.startTickerPreset(preset)"))
    }

    func testOverlayRailUsesIconOnlyTypeLabelAndTailTruncatedPresetName() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains(".truncationMode(.tail)"))
        XCTAssertFalse(source.contains(".frame(width: 70, alignment: .leading)"))
        XCTAssertTrue(source.contains(".help(model.title)"))
    }

    func testLiveOverlayQuickActionsUseProtectedHitTargetHeight() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains(".frame(height: LiveModeLayoutMetrics.quickActionButtonHeight)"))
        XCTAssertFalse(source.contains(".frame(height: 30)"))
    }

    func testAudioAndOverlaySubtitlesUseChineseCopy() throws {
        let audio = try sourceText("Views/AudioMixerView.swift")
        let overlays = try sourceText("Views/SettingsView.swift")

        XCTAssertTrue(audio.contains("调音推子、音频策略、BGM 库三块独立管理"))
        XCTAssertTrue(audio.contains("分类、曲目列表、添加、删除和排序集中在音频页管理"))
        XCTAssertTrue(overlays.contains("左侧编辑，右侧实时预览"))
        XCTAssertFalse(audio.contains("routing strategy 和 BGM library 分区管理"))
        XCTAssertFalse(audio.contains("Categorize, list, add, remove, and reorder BGM tracks here."))
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
