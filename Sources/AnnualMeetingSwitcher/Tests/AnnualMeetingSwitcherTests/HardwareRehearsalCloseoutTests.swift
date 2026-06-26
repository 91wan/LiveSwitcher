import AppKit
import XCTest
@testable import LiveSwitcher

@MainActor
final class HardwareRehearsalCloseoutTests: XCTestCase {
    func testBGMPauseResumeTwentyCyclesPreservesTimeGenerationAndSingleTimerEffects() {
        let item = bgmItem(title: "Middle Track")
        var state = playingBGMState(item: item, generation: 12)
        state.bgm.currentTime = 31.7
        state.bgm.duration = 120
        state.bgm.progress = 31.7 / 120

        for cycle in 1...20 {
            let paused = reduce(state, .operatorToggledCurrentBGMPlayback)

            XCTAssertEqual(paused.state.bgm.phase, .paused, "cycle \(cycle)")
            XCTAssertEqual(paused.state.bgm.generation, 12, "cycle \(cycle)")
            XCTAssertEqual(paused.state.bgm.currentTime, 31.7, accuracy: 0.001, "cycle \(cycle)")
            XCTAssertEqual(paused.state.bgm.duration, 120, "cycle \(cycle)")
            XCTAssertEqual(effectCount(.pauseBGM(generation: 12), in: paused.effects), 1, "cycle \(cycle)")
            XCTAssertEqual(effectCount(.stopBGMTimer(generation: 12), in: paused.effects), 1, "cycle \(cycle)")
            XCTAssertFalse(paused.effects.contains(.prepareBGM(item, generation: 12)), "cycle \(cycle)")
            XCTAssertFalse(paused.effects.contains(.seekBGMToBeginning(generation: 12)), "cycle \(cycle)")

            let resumed = reduce(paused.state, .operatorToggledCurrentBGMPlayback)

            XCTAssertEqual(resumed.state.bgm.phase, .playing, "cycle \(cycle)")
            XCTAssertEqual(resumed.state.bgm.generation, 12, "cycle \(cycle)")
            XCTAssertEqual(resumed.state.bgm.currentTime, 31.7, accuracy: 0.001, "cycle \(cycle)")
            XCTAssertEqual(resumed.state.bgm.duration, 120, "cycle \(cycle)")
            XCTAssertEqual(effectCount(.playBGM(generation: 12), in: resumed.effects), 1, "cycle \(cycle)")
            XCTAssertEqual(effectCount(.startBGMTimer(generation: 12), in: resumed.effects), 1, "cycle \(cycle)")
            XCTAssertFalse(resumed.effects.contains(.prepareBGM(item, generation: 12)), "cycle \(cycle)")
            XCTAssertFalse(resumed.effects.contains(.seekBGMToBeginning(generation: 12)), "cycle \(cycle)")

            state = resumed.state
        }
    }

    func testExplicitBGMStopResetsToZeroAndNextPlayStartsFreshGeneration() {
        let item = bgmItem(title: "Stop Then Play")
        var state = playingBGMState(item: item, generation: 4)
        state.bgm.currentTime = 44
        state.bgm.duration = 100
        state.bgm.progress = 0.44

        let stopped = reduce(state, .operatorStoppedBGM)

        XCTAssertEqual(stopped.state.bgm.phase, .selected)
        XCTAssertEqual(stopped.state.bgm.generation, 5)
        XCTAssertEqual(stopped.state.bgm.currentID, item.id)
        XCTAssertEqual(stopped.state.bgm.currentTime, 0)
        XCTAssertEqual(stopped.state.bgm.progress, 0)
        XCTAssertNil(stopped.state.bgm.duration)
        XCTAssertTrue(stopped.effects.contains(.stopBGM(fade: AudioRoutingDefaults.liveAudioFadeDuration, generation: 5)))
        XCTAssertTrue(stopped.effects.contains(.stopBGMTimer(generation: 5)))

        let replayed = reduce(stopped.state, .operatorToggledCurrentBGMPlayback)

        XCTAssertEqual(replayed.state.bgm.phase, .playing)
        XCTAssertEqual(replayed.state.bgm.generation, 6)
        XCTAssertEqual(replayed.state.bgm.currentTime, 0)
        XCTAssertEqual(replayed.state.bgm.progress, 0)
        XCTAssertNil(replayed.state.bgm.duration)
        XCTAssertTrue(replayed.effects.contains(.prepareBGM(item, generation: 6)))
        XCTAssertTrue(replayed.effects.contains(.playBGM(generation: 6)))
        XCTAssertTrue(replayed.effects.contains(.startBGMTimer(generation: 6)))
    }

    func testBGMChooserCoversFirstMiddleLastPausedRowsSearchAndCanonicalMixedPersistence() throws {
        let tracks = (1...51).map { index in
            BGMItem(
                title: "Hardware Track \(String(format: "%02d", index))",
                url: URL(fileURLWithPath: "/tmp/hardware-track-\(index).mp3"),
                category: index.isMultiple(of: 2) ? .warmUp : .award
            )
        }

        let fullChooser = LiveBGMChooserModel.make(
            items: tracks,
            currentItem: nil,
            phase: .idle,
            selectedCategory: nil,
            searchText: ""
        )
        XCTAssertEqual(fullChooser.totalCount, 51)
        XCTAssertEqual(fullChooser.rows.count, 51)

        let searched = LiveBGMChooserModel.make(
            items: tracks,
            currentItem: nil,
            phase: .idle,
            selectedCategory: nil,
            searchText: "track 50"
        )
        XCTAssertEqual(searched.rows.map(\.id), [tracks[49].id])

        for index in [0, 25, 50] {
            let current = tracks[index]
            let chooser = LiveBGMChooserModel.make(
                items: tracks,
                currentItem: current,
                phase: .paused,
                selectedCategory: nil,
                searchText: ""
            )
            let row = try XCTUnwrap(chooser.rows.first { $0.id == current.id })
            XCTAssertEqual(row.stateText, "已暂停")
            XCTAssertEqual(row.systemImage, "play.fill")
            XCTAssertTrue(row.accessibilityLabel.contains("当前 BGM，已暂停"))

            let controls = BGMControlsState.make(items: tracks, currentItem: current, phase: .paused)
            XCTAssertEqual(controls.displayStatusText, "已暂停")
            XCTAssertEqual(controls.displayStatusKind, .idle)
        }

        XCTAssertEqual(AudioStrategy(persistedValue: AudioStrategy.mixed.rawValue), .mixed)
        XCTAssertEqual(AudioStrategy(persistedValue: "混合"), .mixed)
    }

    func testOverlayGeometryCoversCanvasSizesLayerCombinationsCornersAndPriority() {
        let canvasSizes = [
            CGSize(width: 1280, height: 720),
            CGSize(width: 1920, height: 1080),
            CGSize(width: 3840, height: 2160)
        ]
        let layerCombinations: [(ticker: Bool, countdown: Bool, lowerThird: Bool)] = [
            (false, false, false),
            (true, false, false),
            (false, true, false),
            (false, false, true),
            (true, true, false),
            (true, false, true),
            (false, true, true),
            (true, true, true)
        ]

        for size in canvasSizes {
            let tickerGeometry = TickerTrackGeometry(containerWidth: size.width, measuredTextWidth: 640)
            XCTAssertGreaterThan(tickerGeometry.initialOffsetA, size.width)
            XCTAssertEqual(
                tickerGeometry.nextOffset(after: tickerGeometry.resetThreshold),
                tickerGeometry.initialOffsetA,
                accuracy: 0.001
            )

            let typography = LowerThirdTypographyMetrics.metrics(forCanvasHeight: size.height, canvasWidth: size.width)
            XCTAssertGreaterThanOrEqual(typography.nameFontSize, 36)
            XCTAssertLessThanOrEqual(typography.nameFontSize, 54)
            XCTAssertGreaterThanOrEqual(typography.roleFontSize, 22)
            XCTAssertLessThanOrEqual(typography.roleFontSize, 34)
            XCTAssertGreaterThanOrEqual(typography.organizationFontSize, 20)
            XCTAssertLessThanOrEqual(typography.organizationFontSize, 30)
            XCTAssertLessThanOrEqual(typography.maxWidth, size.width * 0.62)

            for combination in layerCombinations {
                for corner in CornerLogoPosition.allCases {
                    let plan = OutputOverlayLayoutPlan.make(
                        canvasSize: size,
                        isTickerActive: combination.ticker,
                        isCountdownActive: combination.countdown,
                        isLowerThirdVisible: combination.lowerThird,
                        isLogoReady: true,
                        logoPosition: corner
                    )

                    XCTAssertEqual(plan.tickerFrame != nil, combination.ticker)
                    XCTAssertEqual(plan.countdownFrame != nil, combination.countdown)
                    XCTAssertEqual(plan.lowerThirdFrame != nil, combination.lowerThird)
                    XCTAssertNotNil(plan.logoFrame)
                    XCTAssertPlanFramesInsideCanvas(plan, canvasSize: size)

                    if let tickerFrame = plan.tickerFrame {
                        XCTAssertEqual(tickerFrame.origin, .zero)
                        XCTAssertEqual(tickerFrame.width, size.width, accuracy: 0.001)
                        XCTAssertEqual(tickerFrame.height, OutputOverlayLayoutMetrics.tickerHeight, accuracy: 0.001)
                    }

                    if let logoFrame = plan.logoFrame {
                        if let tickerFrame = plan.tickerFrame {
                            XCTAssertFalse(logoFrame.intersects(tickerFrame), "\(size) \(corner)")
                        }
                        if let lowerThirdFrame = plan.lowerThirdFrame {
                            XCTAssertFalse(logoFrame.intersects(lowerThirdFrame), "\(size) \(corner)")
                        }
                    }
                }
            }
        }

        XCTAssertLessThan(OutputLayerZIndex.cornerLogo, OutputLayerZIndex.fadeToBlack)
        XCTAssertLessThan(OutputLayerZIndex.fadeToBlack, OutputLayerZIndex.panic)
    }

    func testWallpaperAndLogoReadinessShareDecodedMonitorOutputSourcesWithoutURLReload() throws {
        let viewModel = makeViewModel()
        let first = try temporaryImageURL(named: "first-wallpaper.png", color: .systemRed)
        let second = try temporaryImageURL(named: "second-wallpaper.png", color: .systemBlue)
        viewModel.backgroundWallpapers = [first, second]

        viewModel.setActiveWallpaper(url: first)
        let firstImage = viewModel.backgroundImage
        viewModel.setActiveWallpaper(url: second)
        let secondImage = viewModel.backgroundImage

        XCTAssertEqual(viewModel.activeWallpaperURL, second)
        XCTAssertNotNil(firstImage)
        XCTAssertNotNil(secondImage)
        XCTAssertFalse(firstImage === secondImage)

        let output = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Output/OutputWindowController.swift")
        let monitor = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitorView.swift")
        let overlay = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ActiveProgramOverlayLayer.swift")

        XCTAssertTrue(output.contains("StandbyWallpaperLayer(image: viewModel.backgroundImage)"))
        XCTAssertTrue(monitor.contains("StandbyWallpaperLayer(image: viewModel.backgroundImage)"))
        XCTAssertFalse(output.contains("NSImage(contentsOf:"))
        XCTAssertFalse(monitor.contains("NSImage(contentsOf:"))
        XCTAssertTrue(overlay.contains("displayState.shouldRenderCornerLogo(hasDecodedImage: cornerLogoImage != nil)"))
        XCTAssertFalse(output.contains("cornerLogoURL"))
    }

    func testMediaReturnPauseResumeAndEndedContractsStaySeparated() throws {
        let item = try mediaProgram(title: "Video A")
        var runtimeState = mediaRuntimeState(for: item, isPlaying: true)

        let returned = LiveRuntimeReducer.reduce(
            state: runtimeState,
            action: .operatorReturnedCurrentMediaToStart,
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        )

        XCTAssertFalse(returned.state.media.isPlaying)
        XCTAssertEqual(returned.state.media.currentTime, 0)
        XCTAssertTrue(returned.effects.contains(.pauseMedia(generation: runtimeState.media.generation)))
        XCTAssertTrue(returned.effects.contains(.seekMediaToStart(generation: runtimeState.media.generation)))
        XCTAssertFalse(returned.effects.contains(.playMedia(generation: runtimeState.media.generation)))
        XCTAssertFalse(returned.effects.contains(.restartMedia(generation: runtimeState.media.generation)))

        let coordinator = AVPlayerCoordinator()
        let url = try XCTUnwrap(item.sourceURL)
        coordinator.load(url: url)
        coordinator.play()
        let loadedItem = coordinator.player.currentItem
        coordinator.pause()

        XCTAssertTrue(VideoLayerVisibilityModel.shouldShowMonitorVideoLayer(
            sourceKind: .media,
            hasLoadedMedia: coordinator.hasLoadedMedia
        ))
        XCTAssertFalse(VideoLayerVisibilityModel.shouldShowOutputVideoLayer(
            sourceKind: .media,
            hasLoadedMedia: coordinator.hasLoadedMedia,
            isPlaying: coordinator.isPlaying
        ))

        coordinator.play()

        XCTAssertTrue(coordinator.player.currentItem === loadedItem)
        XCTAssertTrue(coordinator.isPlaying)

        runtimeState.media.isPlaying = true
        let ended = LiveRuntimeReducer.reduce(
            state: runtimeState,
            action: .mediaReachedEnd(generation: runtimeState.media.generation),
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        )
        XCTAssertFalse(ended.state.media.isPlaying)
        XCTAssertTrue(ended.state.media.didPlayToEnd)

        let viewModel = makeViewModel()
        let next = try mediaProgram(title: "Video B")
        viewModel.addProgramItems([item, next])
        viewModel.switchToProgram(item)
        viewModel.autoPlayNextVideoOnEnd = false
        viewModel.handlePlaybackEnded()
        XCTAssertNotEqual(viewModel.currentProgramItem?.id, next.id)

        let autoNextViewModel = makeViewModel()
        autoNextViewModel.addProgramItems([item, next])
        autoNextViewModel.switchToProgram(item)
        autoNextViewModel.autoPlayNextVideoOnEnd = true
        autoNextViewModel.handlePlaybackEnded()
        XCTAssertEqual(autoNextViewModel.currentProgramItem?.id, next.id)
    }

    func testCanonicalRunbookContainsHardwareRehearsalMatrixWithScopedHumanPassClaims() throws {
        let runbook = try repositorySource("docs/qa/release-candidate-rehearsal.md")

        XCTAssertTrue(runbook.contains("swift test --package-path Sources/AnnualMeetingSwitcher"))
        XCTAssertFalse(runbook.contains("cd Sources/AnnualMeetingSwitcher && swift test"))
        XCTAssertTrue(runbook.contains("Latest operator smoke note:"))
        XCTAssertTrue(runbook.contains("Operator approved merging the current numbered-badge and BGM return-to-start PRs"))
        XCTAssertTrue(runbook.contains("Operator manually tested and approved the live-ops rail chrome and blackout monitor status PRs"))
        XCTAssertTrue(runbook.contains("Operator confirmed manual test acceptance in Codex thread for the current production app"))
        XCTAssertTrue(runbook.contains("No detailed hardware matrix row results"))

        for scenario in operatorAcceptedHumanScenarios {
            XCTAssertTrue(runbook.contains("| \(scenario) | PASS | Operator manually tested and approved PR #375/#376 in Codex thread. |"), scenario)
            XCTAssertFalse(runbook.contains("| \(scenario) | NOT RUN |"), scenario)
        }

        for scenario in stableAcceptedScenarios {
            XCTAssertTrue(runbook.contains("| \(scenario) | PASS |"), scenario)
            XCTAssertFalse(runbook.contains("| \(scenario) | NOT RUN |"), scenario)
        }

        for scenario in notRunHumanScenarios {
            XCTAssertTrue(runbook.contains("| \(scenario) | NOT RUN | |"), scenario)
            XCTAssertFalse(runbook.contains("| \(scenario) | PASS |"), scenario)
        }
    }

    private var operatorAcceptedHumanScenarios: [String] {
        [
            "准备页右侧现场控制侧栏外壳与左侧对称",
            "右侧现场控制底部 footer 对齐",
            "切黑监看同步黑场",
            "紧急切黑监看同步黑场",
            "App monitor 显示 blackout 原因",
            "外接屏不显示本地 blackout 状态文字"
        ]
    }

    private var notRunHumanScenarios: [String] {
        [
            "旧人名条 JSON 无损迁移",
            "姓名+职位同一行",
            "公司名称第二行",
            "长文本缩放与 720/1080/4K",
            "进度轨道使用整行主要宽度",
            "进度拖动仍走 Runtime",
            "节目拖出列表后释放不重排",
            "演示就绪汇总条已移除",
            "readiness 行内提示全中文",
            "拖入提示为一行",
            "准备页主监看水平居中",
            "现场叠层全部清空",
            "Monitor/Output 清空无残留",
            "节目单首尾拖拽排序",
            "当前节目移动不打断播放",
            "排序后重启仍保留",
            "拖拽不误触节目切换",
            "三种新建按钮文案与跳转",
            "Monitor 人名条同步",
            "Monitor 倒计时实时同步",
            "Monitor ticker 同步",
            "Monitor 三叠层组合",
            "Monitor 清空无残留",
            "媒体进度拖动 25%/75%",
            "seek 时切换视频的 stale 防护",
            "多项删除无误删/崩溃",
            "BGM 30s 暂停/原位恢复",
            "BGM pause/resume 20 次",
            "BGM 显式 stop 后从 0 开始",
            "现场任意曲目选择/搜索",
            "1080p ticker 顶边全宽",
            "4K/缩放 ticker 顶边全宽",
            "ticker 文字从右侧画外进入",
            "8 种叠层组合",
            "人名条可读性",
            "Logo 四角与无碰撞",
            "Logo 换图/失败/移除/重启",
            "壁纸监看实时更新",
            "监看与副屏壁纸裁切一致",
            "回到片头不播放",
            "视频 pause/resume 20 次",
            "ended + auto-next off/on",
            "主持人/PPT 整卡命中",
            "切黑/Panic 抢占恢复",
            "Toggle/Button/Slider 焦点下 Space/数字不被抢走",
            "紧急快捷键在输入焦点下仍有效",
            "公司名称设置/恢复默认",
            "四个顶部标题同步",
            "长公司名称最小窗口布局",
            "Support Report 不泄漏公司名",
            "Logo 显示/隐藏即时切换",
            "隐藏 Logo 重启恢复",
            "隐藏状态替换/失败保留",
            "Monitor/外屏 Logo 同步",
            "新建 agenda marker",
            "编辑 marker 标题/时间/时长",
            "旧 Break 数据不丢失",
            "marker 在 Live rail 不可误点",
            "“到点提醒”标签清晰",
            "无 current 的第一项提醒",
            "marker 到点提醒",
            "idle 等待仍准时提醒",
            "提醒不自动切换",
            "提醒 Timer/clock 无残留",
            "60 分钟 soak",
            "准备页节目编号可读",
            "现场节目编号可读",
            "10+ 节目编号不裁剪",
            "marker cue row 编号可读",
            "现场 1.5–2 米距离编号可读",
            "BGM 播放中回到开头微淡化",
            "BGM 暂停中回到开头仍暂停",
            "BGM 静音/主持人模式回到开头无异常",
            "快速连续回到开头不串音",
            "BGM 切歌中回到开头不拉高旧歌",
            "Stable 60-minute soak"
        ]
    }

    private var stableAcceptedScenarios: [String] {
        [
            "Stable final automated gates",
            "Stable final app hash recorded",
            "Stable final human acceptance recorded"
        ]
    }

    private func reduce(_ state: LiveRuntimeState, _ action: LiveRuntimeAction) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: .productionBGMOwning()
        )
    }

    private func effectCount(_ effect: LiveRuntimeEffect, in effects: [LiveRuntimeEffect]) -> Int {
        effects.filter { $0 == effect }.count
    }

    private func bgmItem(title: String) -> BGMItem {
        BGMItem(title: title, url: URL(fileURLWithPath: "/tmp/\(title).mp3"), category: .warmUp)
    }

    private func playingBGMState(item: BGMItem, generation: Int) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        state.bgm.currentID = item.id
        state.bgm.phase = .playing
        state.bgm.generation = generation
        state.audio.routingContext.isBGMPlaying = true
        return state
    }

    private func XCTAssertPlanFramesInsideCanvas(
        _ plan: OutputOverlayLayoutPlan,
        canvasSize: CGSize,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let canvas = CGRect(origin: .zero, size: canvasSize)
        for frame in [plan.tickerFrame, plan.countdownFrame, plan.lowerThirdFrame, plan.logoFrame].compactMap({ $0 }) {
            XCTAssertTrue(canvas.contains(frame), "\(frame) should fit in \(canvas)", file: file, line: line)
        }
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "HardwareRehearsalCloseoutTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
    }

    private func mediaRuntimeState(for item: ProgramItem, isPlaying: Bool) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.program.items = [item]
        state.program.currentID = item.id
        state.media.loadedURL = item.sourceURL
        state.media.isPlaying = isPlaying
        state.media.duration = 60
        state.media.generation = 3
        state.audio.routingContext.isCurrentProgramMediaSource = true
        state.audio.routingContext.isMediaPlaying = isPlaying
        return state
    }

    private func mediaProgram(title: String) throws -> ProgramItem {
        ProgramItem(title: title, subtitle: "VIDEO", sourceURL: try temporaryFile(ext: "mp4"))
    }

    private func temporaryFile(ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try Data("fixture".utf8).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func temporaryImageURL(named name: String, color: NSColor) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiveSwitcherHardwareRehearsalCloseoutTests", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(UUID().uuidString)-\(name)")
        let image = NSImage(size: NSSize(width: 12, height: 8))
        image.lockFocus()
        color.setFill()
        NSRect(x: 0, y: 0, width: 12, height: 8).fill()
        image.unlockFocus()
        let data = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
