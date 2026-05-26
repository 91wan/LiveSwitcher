import XCTest
@testable import LiveSwitcher

final class LiveModeMixerControlsTests: XCTestCase {
    func testAudioMeterModelMapsMutedRealtimeAndEstimatedLevels() {
        let muted = LiveAudioMeterModel.make(effectiveVolume: 0, isMuted: true)
        XCTAssertEqual(muted.level, 0)
        XCTAssertEqual(muted.decibelText, "-∞ dB")
        XCTAssertEqual(muted.statusKind, .muted)
        XCTAssertFalse(muted.isEstimated)

        let realtime = LiveAudioMeterModel.make(realtimeDB: -12, fallbackEffectiveVolume: 1, isMuted: false)
        XCTAssertEqual(realtime.level, 0.8, accuracy: 0.01)
        XCTAssertEqual(realtime.decibelText, "-12 dB")
        XCTAssertEqual(realtime.statusKind, .ready)
        XCTAssertFalse(realtime.isEstimated)

        let realtimeWithGain = LiveAudioMeterModel.make(realtimeDB: -6, fallbackEffectiveVolume: 0.5, isMuted: false)
        XCTAssertEqual(realtimeWithGain.decibelText, "-12 dB")
        XCTAssertFalse(realtimeWithGain.isEstimated)

        let clipping = LiveAudioMeterModel.make(realtimeDB: -1, fallbackEffectiveVolume: 0.2, isMuted: false)
        XCTAssertEqual(clipping.decibelText, "-15 dB")
        XCTAssertEqual(clipping.statusKind, .ready)
        XCTAssertFalse(clipping.isEstimated)

        let realtimeClipping = LiveAudioMeterModel.make(realtimeDB: -1, fallbackEffectiveVolume: 1, isMuted: false)
        XCTAssertEqual(realtimeClipping.decibelText, "-1 dB")
        XCTAssertEqual(realtimeClipping.statusKind, .warn)
        XCTAssertFalse(realtimeClipping.isEstimated)

        let realtimeWithClosedFader = LiveAudioMeterModel.make(realtimeDB: -1, fallbackEffectiveVolume: 0, isMuted: false)
        XCTAssertEqual(realtimeWithClosedFader.decibelText, "-∞ dB")
        XCTAssertEqual(realtimeWithClosedFader.statusKind, .muted)
        XCTAssertFalse(realtimeWithClosedFader.isEstimated)

        let realtimeOverload = LiveAudioMeterModel.make(realtimeDB: 3, fallbackEffectiveVolume: 1, isMuted: false)
        XCTAssertEqual(realtimeOverload.decibelText, "0 dB")
        XCTAssertEqual(realtimeOverload.statusKind, .warn)
        XCTAssertFalse(realtimeOverload.isEstimated)

        let estimated = LiveAudioMeterModel.make(realtimeDB: nil, fallbackEffectiveVolume: 0.5, isMuted: false)
        XCTAssertGreaterThan(estimated.level, 0)
        XCTAssertLessThan(estimated.level, 1)
        XCTAssertEqual(estimated.decibelText, "≈ -6 dB")
        XCTAssertEqual(estimated.statusKind, .ready)
        XCTAssertTrue(estimated.isEstimated)
    }

    func testCutBusModelEnablesTakeNextOnlyWhenQueueHasNextItem() {
        let current = ProgramItem(id: UUID(), title: "Opening", subtitle: "MP4")
        let next = ProgramItem(id: UUID(), title: "Awards", subtitle: "HTML")

        let noNext = LiveCutBusModel.make(programItems: [current], currentProgramItem: current)
        XCTAssertFalse(noNext.canTakeNext)
        XCTAssertNil(noNext.nextIndex)
        XCTAssertEqual(noNext.nextTitle, "没有下一项")

        let hasNext = LiveCutBusModel.make(programItems: [current, next], currentProgramItem: current)
        XCTAssertTrue(hasNext.canTakeNext)
        XCTAssertEqual(hasNext.nextIndex, 1)
        XCTAssertEqual(hasNext.nextTitle, "Awards")
    }

    func testRuntimeStatusModelPrioritizesPreflightExceptions() {
        var snapshot = LivePreflightSnapshot.fixture(
            hasExternalDisplay: false,
            isBroadcasting: false,
            currentProgramTitle: nil,
            wallpaperCount: 1,
            effectiveMediaVolume: 0.5,
            effectiveBGMVolume: 0.4
        )

        let fail = LiveRuntimeStatusModel.make(snapshot: snapshot)
        XCTAssertEqual(fail.kind, .fail)
        XCTAssertTrue(fail.text.contains("外接显示器"))

        snapshot = LivePreflightSnapshot.fixture(
            hasExternalDisplay: true,
            isBroadcasting: false,
            currentProgramTitle: "Opening",
            wallpaperCount: 1,
            effectiveMediaVolume: 0.5,
            effectiveBGMVolume: 0.4
        )
        let warn = LiveRuntimeStatusModel.make(snapshot: snapshot)
        XCTAssertEqual(warn.kind, .warn)
        XCTAssertTrue(warn.text.contains("投射状态"))

        snapshot = LivePreflightSnapshot.fixture(
            hasExternalDisplay: true,
            isBroadcasting: true,
            currentProgramTitle: "Opening",
            wallpaperCount: 1,
            effectiveMediaVolume: 0.5,
            effectiveBGMVolume: 0.4
        )
        let ready = LiveRuntimeStatusModel.make(snapshot: snapshot)
        XCTAssertEqual(ready.kind, .live)
        XCTAssertTrue(ready.text.contains("当前: Opening"))
    }

    func testRuntimeStatusModelExposesExceptionChipsAndSummaryTogether() {
        let snapshot = LivePreflightSnapshot.fixture(
            hasExternalDisplay: false,
            isBroadcasting: false,
            currentProgramTitle: nil,
            wallpaperCount: 0,
            effectiveMediaVolume: 0,
            effectiveBGMVolume: 0
        )

        let checks = LivePreflightCheck.build(from: snapshot) + [
            LivePreflightCheck(
                id: "synthetic.fail",
                group: .display,
                status: .fail,
                title: "Synthetic Issue",
                message: "Extra blocking issue"
            ),
            LivePreflightCheck(
                id: "synthetic.fail.2",
                group: .display,
                status: .fail,
                title: "Synthetic Issue 2",
                message: "Extra blocking issue"
            ),
            LivePreflightCheck(
                id: "synthetic.warn",
                group: .audio,
                status: .warn,
                title: "Synthetic Warning",
                message: "Extra warning"
            )
        ]

        let model = LiveRuntimeStatusModel.make(checks: checks, snapshot: snapshot)

        XCTAssertGreaterThanOrEqual(model.chips.count, 3)
        XCTAssertTrue(model.chips.contains { $0.kind == .fail && $0.text.contains("外接显示器") })
        XCTAssertTrue(model.chips.contains { $0.kind == .warn && $0.text.contains("投射状态") })
        XCTAssertTrue(model.chips.contains { $0.text.contains("+") && $0.text.contains("问题") })
        XCTAssertTrue(model.chips.contains { $0.text.contains("待机") && $0.text.contains("0 个信号源") })
    }

    @MainActor
    func testMasterMeterUsesRealtimeBGMWhenAvailable() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.masterVolume = 0.8
        viewModel.bgmVolume = 0.5
        viewModel.isBGMPlaying = true
        viewModel.bgmRealtimeLevelDB = -18

        XCTAssertEqual(viewModel.liveMasterMeterRealtimeDB(), -18)
        XCTAssertEqual(viewModel.liveMasterMeterFallbackVolume(), viewModel.effectiveBGMOutputVolume())
    }

    @MainActor
    func testMasterMeterUsesRealtimeMediaWhenMediaIsLouder() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.masterVolume = 1
        viewModel.mediaVolume = 1
        viewModel.bgmVolume = 0.1
        viewModel.currentProgramItem = ProgramItem(
            title: "Clip",
            subtitle: "MP4",
            sourceURL: URL(fileURLWithPath: "/tmp/clip.mp4")
        )
        viewModel.avCoordinator.isPlaying = true
        viewModel.avCoordinator.realtimeLevelDB = -9
        viewModel.bgmRealtimeLevelDB = -24
        viewModel.isBGMPlaying = true

        XCTAssertEqual(viewModel.liveMasterMeterRealtimeDB(), -9)
        XCTAssertEqual(viewModel.liveMasterMeterFallbackVolume(), viewModel.effectiveMediaOutputVolume())
    }

    @MainActor
    func testMasterMeterChoosesRealtimeSourceAfterFaderGain() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.masterVolume = 1
        viewModel.mediaVolume = 0.1
        viewModel.bgmVolume = 1
        viewModel.avCoordinator.isPlaying = true
        viewModel.avCoordinator.realtimeLevelDB = -6
        viewModel.bgmRealtimeLevelDB = -18
        viewModel.isBGMPlaying = true

        XCTAssertEqual(viewModel.liveMasterMeterRealtimeDB(), -18)
        XCTAssertEqual(viewModel.liveMasterMeterFallbackVolume(), viewModel.effectiveBGMOutputVolume())
    }

    @MainActor
    func testMasterMeterIgnoresPausedMediaRealtimeLevel() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.masterVolume = 1
        viewModel.mediaVolume = 1
        viewModel.avCoordinator.isPlaying = false
        viewModel.avCoordinator.realtimeLevelDB = -3
        viewModel.bgmRealtimeLevelDB = -24
        viewModel.isBGMPlaying = true

        XCTAssertEqual(viewModel.liveMasterMeterRealtimeDB(), -24)
        XCTAssertEqual(viewModel.liveMasterMeterFallbackVolume(), viewModel.effectiveBGMOutputVolume())
    }

    @MainActor
    func testMasterMeterFallsBackToEffectiveOutputWhenRealtimeUnavailable() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.masterVolume = 0.7
        viewModel.bgmVolume = 0.4
        viewModel.bgmRealtimeLevelDB = nil

        XCTAssertNil(viewModel.liveMasterMeterRealtimeDB())
        XCTAssertEqual(
            viewModel.liveMasterMeterFallbackVolume(),
            max(viewModel.effectiveMediaOutputVolume(), viewModel.effectiveBGMOutputVolume())
        )
    }

    func testLiveAudioStripShowsStrategyTogetherWithActiveLimiter() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("audioStrategy.displayTitle"))
        XCTAssertTrue(source.contains("· 主持人"))
        XCTAssertTrue(source.contains("· BGM 接管"))
        XCTAssertTrue(source.contains("· 紧急切黑"))
        XCTAssertFalse(source.contains("private var audioStatusText: String {\n        viewModel.audioStrategy.displayTitle\n    }"))
    }

    @MainActor
    func testFadeToBlackDoesNotTogglePanicOrMuteAudio() {
        let suite = "FadeToBlack-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            XCTFail("Could not create isolated defaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
        viewModel.isMasterAudioMuted = false
        viewModel.isMediaAudioMuted = false
        viewModel.isBGMAudioMuted = false

        viewModel.toggleFadeToBlack()

        XCTAssertTrue(viewModel.isFadeToBlackActive)
        XCTAssertFalse(viewModel.isPanicMode)
        XCTAssertFalse(viewModel.isMasterAudioMuted)
        XCTAssertFalse(viewModel.isMediaAudioMuted)
        XCTAssertFalse(viewModel.isBGMAudioMuted)
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .fadeToBlackChanged })
    }

    func testLiveModeViewContainsMetersMuteButtonsAndCutBus() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("LiveAudioMeter"))
        XCTAssertTrue(source.contains("isMasterAudioMuted"))
        XCTAssertTrue(source.contains("isMediaAudioMuted"))
        XCTAssertTrue(source.contains("isBGMAudioMuted"))
        XCTAssertTrue(source.contains("viewModel.isPanicMode || viewModel.isMasterAudioMuted"))
        XCTAssertTrue(source.contains("切换"))
        XCTAssertTrue(source.contains("下一项"))
    }

    func testBGMPlayerEnablesRealtimeMetering() throws {
        let source = try sourceText("ViewModel.swift")

        XCTAssertTrue(source.contains("bgmRealtimeLevelDB"))
        XCTAssertTrue(source.contains("player.isMeteringEnabled = true"))
        XCTAssertTrue(source.contains("averagePower(forChannel: 0)"))
    }

    func testLiveAudioStripUsesRealtimeBGMMeter() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("realtimeDB: viewModel.liveMasterMeterRealtimeDB()"))
        XCTAssertTrue(source.contains("fallbackEffectiveVolume: viewModel.liveMasterMeterFallbackVolume()"))
        XCTAssertTrue(source.contains("realtimeDB: viewModel.avCoordinator.realtimeLevelDB"))
        XCTAssertTrue(source.contains("realtimeDB: viewModel.bgmRealtimeLevelDB"))
        XCTAssertTrue(source.contains("fallbackEffectiveVolume: viewModel.effectiveBGMOutputVolume()"))
    }

    func testAVPlayerCoordinatorInstallsMediaAudioMeterTap() throws {
        let source = try sourceText("Engines/AVPlayerCoordinator.swift")

        XCTAssertTrue(source.contains("MediaAudioMeterTap"))
        XCTAssertTrue(source.contains("realtimeLevelDB"))
        XCTAssertTrue(source.contains("installMeterTap"))
    }

    func testLiveAudioFaderMarksEstimatedMeters() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("meter.isEstimated"))
        XCTAssertTrue(source.contains("exclamationmark.triangle.fill"))
        XCTAssertTrue(source.contains("估算电平"))
    }

    func testCutBusUsesFadeToBlackInsteadOfPanic() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("viewModel.toggleFadeToBlack()"))
        XCTAssertTrue(source.contains("从 FTB 恢复"))
        XCTAssertFalse(source.contains("viewModel.togglePanicMode()"))
    }

    func testCutBusMakesTakeNextPrimaryAndFTBSecondary() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("Label(\"下一项\", systemImage: \"arrow.right.to.line.compact\")"))
        XCTAssertTrue(source.contains(".frame(maxWidth: .infinity)"))
        XCTAssertTrue(source.contains(".tint(StudioTheme.Action.primary)"))
        XCTAssertTrue(source.contains("Label(viewModel.isFadeToBlackActive ? \"恢复\" : \"FTB\""))
        XCTAssertTrue(source.contains("LiveModeLayoutMetrics.ftbButtonWidth"))
    }

    func testLiveModeMuteButtonsUseTransportHitTargetHeight() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertFalse(source.contains("height: 22"))
        XCTAssertTrue(source.contains("height: LiveModeLayoutMetrics.transportButtonSize"))
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

private extension LivePreflightSnapshot {
    static func fixture(
        hasExternalDisplay: Bool,
        isBroadcasting: Bool,
        currentProgramTitle: String?,
        wallpaperCount: Int,
        effectiveMediaVolume: Float,
        effectiveBGMVolume: Float
    ) -> LivePreflightSnapshot {
        LivePreflightSnapshot(
            appVersion: "0.0.0",
            hasExternalDisplay: hasExternalDisplay,
            isBroadcasting: isBroadcasting,
            broadcastSafetyNotice: nil,
            programItemCount: currentProgramTitle == nil ? 0 : 1,
            currentProgramTitle: currentProgramTitle,
            currentProgramSource: currentProgramTitle == nil ? nil : "Media",
            bgmItemCount: 1,
            isBGMPlaying: false,
            isBGMAudioTakeoverActive: false,
            isSpeakerMode: false,
            isPanicMode: false,
            isPageInterceptEnabled: false,
            activeOverlayCount: 0,
            activeOverlayKinds: [],
            countdownRemainingSeconds: nil,
            wallpaperCount: wallpaperCount,
            autoPlayNextVideoOnEnd: false,
            effectiveMediaVolume: effectiveMediaVolume,
            effectiveBGMVolume: effectiveBGMVolume
        )
    }
}
