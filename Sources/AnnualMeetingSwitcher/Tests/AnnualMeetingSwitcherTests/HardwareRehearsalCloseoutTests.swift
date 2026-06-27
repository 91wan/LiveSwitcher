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
        let monitor = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitor/ProgramMonitorPreviewDeck.swift")
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
