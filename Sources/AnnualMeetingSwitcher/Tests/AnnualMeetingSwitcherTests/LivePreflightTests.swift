import AppKit
import XCTest
@testable import LiveSwitcher

@MainActor
final class LivePreflightTests: XCTestCase {
    private func makeViewModel() -> SwitcherViewModel {
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: .standard
        )
        viewModel.externalScreenProvider = { NSScreen.main ?? NSScreen.screens.first }
        viewModel.keynotePresentationHandler = { _ in }
        viewModel.pptxOpenHandler = { _ in }
        viewModel.activeDeckPresentationHandler = {}
        viewModel.invalidDeckHandler = { _ in }
        viewModel.deckStopHandler = {}
        return viewModel
    }

    private func readySnapshot() -> LivePreflightSnapshot {
        LivePreflightSnapshot(
            appVersion: "0.4.0",
            hasExternalDisplay: true,
            isBroadcasting: true,
            broadcastSafetyNotice: nil,
            programItemCount: 1,
            currentProgramTitle: "Opening Video",
            currentProgramSource: "Media",
            bgmItemCount: 1,
            isBGMPlaying: false,
            isBGMAudioTakeoverActive: false,
            isSpeakerMode: false,
            isPanicMode: false,
            isPageInterceptEnabled: false,
            activeOverlayCount: 0,
            wallpaperCount: 1,
            autoPlayNextVideoOnEnd: false,
            effectiveMediaVolume: 0.5,
            effectiveBGMVolume: 0.5
        )
    }

    private func check(
        _ id: String,
        in checks: [LivePreflightCheck],
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> LivePreflightCheck {
        guard let check = checks.first(where: { $0.id == id }) else {
            XCTFail("Missing preflight check: \(id)", file: file, line: line)
            return LivePreflightCheck(
                id: id,
                group: .controls,
                status: .fail,
                title: "missing",
                message: "missing"
            )
        }
        return check
    }

    func testNoExternalDisplayIsNotReadyAndWarnsAgainstProjection() {
        let viewModel = makeViewModel()
        viewModel.externalScreenProvider = { nil }

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let display = check("display.external", in: checks)

        XCTAssertEqual(display.group, .display)
        XCTAssertEqual(display.status, .fail)
        XCTAssertEqual(display.actionKind, .needsHardware)
        XCTAssertEqual(display.actionLabel, "需要硬件")
        XCTAssertTrue(display.message.localizedStandardContains("需要硬件"))
        XCTAssertTrue(display.message.localizedStandardContains("请勿投射"))

        let beforeSnapshot = viewModel.livePreflightSnapshot
        XCTAssertFalse(viewModel.performLivePreflightAction(.needsHardware))
        XCTAssertEqual(viewModel.livePreflightSnapshot, beforeSnapshot)
    }

    func testSummaryFailsWhenAnyCheckFails() {
        var snapshot = readySnapshot()
        snapshot.hasExternalDisplay = false
        snapshot.isBroadcasting = false

        let summary = LivePreflightSummary.make(from: LivePreflightCheck.build(from: snapshot))

        XCTAssertEqual(summary.status, .fail)
        XCTAssertEqual(summary.title, "未就绪")
        XCTAssertEqual(summary.failCount, 1)
        XCTAssertGreaterThan(summary.warnCount, 0)
    }

    func testSummaryWarnsWhenChecksHaveWarningsButNoFailures() {
        var snapshot = readySnapshot()
        snapshot.autoPlayNextVideoOnEnd = true

        let summary = LivePreflightSummary.make(from: LivePreflightCheck.build(from: snapshot))

        XCTAssertEqual(summary.status, .warn)
        XCTAssertEqual(summary.title, "需复核")
        XCTAssertEqual(summary.failCount, 0)
        XCTAssertGreaterThan(summary.warnCount, 0)
    }

    func testSummaryPassesWhenAllChecksPass() {
        let summary = LivePreflightSummary.make(from: LivePreflightCheck.build(from: readySnapshot()))

        XCTAssertEqual(summary.status, .pass)
        XCTAssertEqual(summary.title, "就绪")
        XCTAssertEqual(summary.failCount, 0)
        XCTAssertEqual(summary.warnCount, 0)
        XCTAssertGreaterThan(summary.passCount, 0)
    }

    func testAttentionChecksOnlyReturnsWarningsAndFailures() {
        var snapshot = readySnapshot()
        snapshot.hasExternalDisplay = false
        snapshot.autoPlayNextVideoOnEnd = true

        let checks = LivePreflightCheck.build(from: snapshot)
        let attentionChecks = LivePreflightCheck.attentionChecks(from: checks)

        XCTAssertFalse(attentionChecks.isEmpty)
        XCTAssertTrue(attentionChecks.allSatisfy { $0.status != .pass })
        XCTAssertTrue(attentionChecks.contains { $0.id == "display.external" && $0.status == .fail })
        XCTAssertTrue(attentionChecks.contains { $0.id == "playback.auto-next" && $0.status == .warn })
        XCTAssertFalse(attentionChecks.contains { $0.id == "audio.volumes" })
    }

    func testAttentionChecksEmptyWhenReadySnapshotHasNoWarningsOrFailures() {
        let checks = LivePreflightCheck.build(from: readySnapshot())
        let attentionChecks = LivePreflightCheck.attentionChecks(from: checks)
        let summary = LivePreflightSummary.make(from: checks)

        XCTAssertEqual(summary.status, .pass)
        XCTAssertTrue(attentionChecks.isEmpty)
    }

    func testExternalDisplayPresentPassesDisplayReadiness() {
        let viewModel = makeViewModel()

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let display = check("display.external", in: checks)

        XCTAssertEqual(display.group, .display)
        XCTAssertEqual(display.status, .pass)
        XCTAssertTrue(display.message.localizedStandardContains("已检测到外接显示器"))
    }

    func testPanicModeActiveIsClearlyReportedAsEmergencyState() {
        let viewModel = makeViewModel()
        viewModel.isPanicMode = true

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let panic = check("controls.panic", in: checks)

        XCTAssertEqual(panic.group, .controls)
        XCTAssertEqual(panic.status, .fail)
        XCTAssertEqual(panic.actionKind, .turnOffPanic)
        XCTAssertEqual(panic.actionLabel, "关闭紧急切黑")
        XCTAssertTrue(panic.message.localizedStandardContains("紧急切黑已开启"))

        let attentionChecks = LivePreflightCheck.attentionChecks(from: checks)
        XCTAssertTrue(attentionChecks.contains(panic))

        XCTAssertTrue(viewModel.performLivePreflightAction(.turnOffPanic))
        XCTAssertFalse(viewModel.isPanicMode)
    }

    func testSpeakerModeActiveReportsMediaAndBGMDucking() {
        let viewModel = makeViewModel()
        viewModel.isSpeakerMode = true

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let speaker = check("audio.speaker", in: checks)

        XCTAssertEqual(speaker.group, .audio)
        XCTAssertEqual(speaker.status, .warn)
        XCTAssertTrue(speaker.message.localizedStandardContains("媒体和 BGM 压低已开启"))
    }

    func testBGMTakeoverReportsMediaAudioMutedByTakeover() {
        let viewModel = makeViewModel()
        viewModel.bgmItems = [
            BGMItem(title: "Walk-in Music", url: URL(fileURLWithPath: "/tmp/walk-in.mp3"), category: .warmUp)
        ]
        viewModel.isBGMPlaying = true
        viewModel.isBGMAudioTakeoverActive = true

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let takeover = check("audio.bgm-takeover", in: checks)

        XCTAssertEqual(takeover.group, .audio)
        XCTAssertEqual(takeover.status, .warn)
        XCTAssertEqual(takeover.actionKind, .openAudioMixer)
        XCTAssertEqual(takeover.actionLabel, "打开音频页")
        XCTAssertTrue(takeover.message.localizedStandardContains("媒体声道被 BGM 接管静音"))
    }

    func testNoBGMItemsWarnsAudioReadiness() {
        let viewModel = makeViewModel()
        viewModel.bgmItems = []

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let bgm = check("audio.bgm-library", in: checks)

        XCTAssertEqual(bgm.group, .audio)
        XCTAssertEqual(bgm.status, .warn)
        XCTAssertEqual(bgm.actionKind, .openAudioMixer)
        XCTAssertEqual(bgm.actionLabel, "打开音频页")
        XCTAssertTrue(bgm.message.localizedStandardContains("未载入 BGM 曲目"))
    }

    func testNoWallpaperWarnsPlaybackFallbackReadiness() {
        let viewModel = makeViewModel()
        viewModel.backgroundWallpapers = []

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let wallpaper = check("playback.wallpaper", in: checks)

        XCTAssertEqual(wallpaper.group, .playback)
        XCTAssertEqual(wallpaper.status, .warn)
        XCTAssertEqual(wallpaper.actionKind, .openPreview)
        XCTAssertEqual(wallpaper.actionLabel, "打开节目单")
        XCTAssertTrue(wallpaper.message.localizedStandardContains("尚未载入待机壁纸"))
    }

    func testActiveOverlaysReportOverlayCount() {
        let viewModel = makeViewModel()
        viewModel.startCountdown(seconds: 30, title: "Start")
        viewModel.startTicker(text: "Welcome")
        viewModel.showLowerThird(name: "Host", title: "Opening")

        let snapshot = viewModel.livePreflightSnapshot
        XCTAssertEqual(snapshot.activeOverlayCount, 3)
        XCTAssertEqual(snapshot.activeOverlayKinds, [.countdown, .ticker, .lowerThird])
        XCTAssertEqual(snapshot.countdownRemainingSeconds, 30)

        let checks = LivePreflightCheck.build(from: snapshot)
        let overlays = check("overlays.active", in: checks)

        XCTAssertEqual(overlays.group, .overlays)
        XCTAssertEqual(overlays.status, .warn)
        XCTAssertEqual(overlays.actionKind, .clearOverlays)
        XCTAssertEqual(overlays.actionLabel, "清空叠层")
        XCTAssertTrue(overlays.message.localizedStandardContains("3 个叠层正在上屏"))
        XCTAssertTrue(overlays.message.localizedStandardContains("倒计时"))
        XCTAssertTrue(overlays.message.localizedStandardContains("游动字幕"))
        XCTAssertTrue(overlays.message.localizedStandardContains("人名条"))
        XCTAssertTrue(overlays.message.localizedStandardContains("剩余 30s"))

        let attentionChecks = LivePreflightCheck.attentionChecks(from: checks)
        XCTAssertTrue(attentionChecks.contains(overlays))

        XCTAssertTrue(viewModel.performLivePreflightAction(.clearOverlays))
        XCTAssertFalse(viewModel.isCountdownActive)
        XCTAssertFalse(viewModel.isTickerActive)
        XCTAssertFalse(viewModel.isLowerThirdVisible)
        XCTAssertEqual(viewModel.lowerThirdName, "")
        XCTAssertEqual(viewModel.lowerThirdTitle, "")
    }

    func testOverlayReportsDoNotLeakOverlayContent() {
        let viewModel = makeViewModel()
        viewModel.startCountdown(seconds: 45, title: "Private Show Title")
        viewModel.startTicker(text: "Customer ticker text")
        viewModel.showLowerThird(name: "Private Host", title: "Private Company")

        let preflightReport = viewModel.livePreflightReportText()
        let diagnosticsReport = viewModel.liveDiagnosticsReportText()
        let supportReport = viewModel.liveSupportReportText(
            generatedAt: Date(timeIntervalSince1970: 1_790_000_000)
        )

        for report in [preflightReport, diagnosticsReport, supportReport] {
            XCTAssertTrue(report.localizedStandardContains("倒计时"))
            XCTAssertTrue(report.localizedStandardContains("游动字幕"))
            XCTAssertTrue(report.localizedStandardContains("人名条"))
            XCTAssertTrue(report.localizedStandardContains("剩余 45s"))
            XCTAssertFalse(report.localizedStandardContains("Private Show Title"))
            XCTAssertFalse(report.localizedStandardContains("Customer ticker text"))
            XCTAssertFalse(report.localizedStandardContains("Private Host"))
            XCTAssertFalse(report.localizedStandardContains("Private Company"))
        }
    }

    func testAutoNextWarningRecommendsPreviewReview() {
        let viewModel = makeViewModel()
        viewModel.autoPlayNextVideoOnEnd = true

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let autoNext = check("playback.auto-next", in: checks)

        XCTAssertEqual(autoNext.group, .playback)
        XCTAssertEqual(autoNext.status, .warn)
        XCTAssertEqual(autoNext.actionKind, .openPreview)
        XCTAssertEqual(autoNext.actionLabel, "打开节目单")
    }

    func testPPTModeUsesManualReviewActionWithoutMutatingState() {
        let viewModel = makeViewModel()
        viewModel.isPageInterceptEnabled = true

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let ppt = check("controls.ppt", in: checks)

        XCTAssertEqual(ppt.group, .controls)
        XCTAssertEqual(ppt.status, .warn)
        XCTAssertEqual(ppt.actionKind, .manualReview)
        XCTAssertEqual(ppt.actionLabel, "人工复核")

        let beforeSnapshot = viewModel.livePreflightSnapshot
        XCTAssertFalse(viewModel.performLivePreflightAction(.manualReview))
        XCTAssertEqual(viewModel.livePreflightSnapshot, beforeSnapshot)
    }

    func testPPTModeWarnsWhenEnabledWithoutPageableProgram() {
        var snapshot = readySnapshot()
        snapshot.currentProgramSource = "Media"
        snapshot.isPageInterceptEnabled = true

        let ppt = check("controls.ppt", in: LivePreflightCheck.build(from: snapshot))

        XCTAssertEqual(ppt.status, .warn)
        XCTAssertEqual(ppt.actionKind, .manualReview)
        XCTAssertTrue(ppt.message.localizedStandardContains("当前节目不是可翻页信号源"))
    }

    func testPPTModePassesWhenEnabledForPageableProgram() {
        for source in ["HTML", "Keynote", "PPTX", "Active Keynote Deck"] {
            var snapshot = readySnapshot()
            snapshot.currentProgramSource = source
            snapshot.isPageInterceptEnabled = true

            let ppt = check("controls.ppt", in: LivePreflightCheck.build(from: snapshot))

            XCTAssertEqual(ppt.status, .pass, source)
        }
    }

    func testPPTModeWarnsWhenDeckProgramNeedsPageControlButModeIsOff() {
        for source in ["Keynote", "PPTX", "Active Keynote Deck"] {
            var snapshot = readySnapshot()
            snapshot.currentProgramSource = source
            snapshot.isPageInterceptEnabled = false

            let ppt = check("controls.ppt", in: LivePreflightCheck.build(from: snapshot))

            XCTAssertEqual(ppt.status, .warn, source)
            XCTAssertEqual(ppt.actionKind, .manualReview)
            XCTAssertTrue(ppt.message.localizedStandardContains("当前载入演示信号源"))
        }
    }

    func testNavigationActionsDoNotMutateViewModelState() {
        let viewModel = makeViewModel()
        viewModel.startTicker(text: "Welcome")
        let beforeSnapshot = viewModel.livePreflightSnapshot

        XCTAssertFalse(viewModel.performLivePreflightAction(.openPreview))
        XCTAssertFalse(viewModel.performLivePreflightAction(.openAudioMixer))
        XCTAssertFalse(viewModel.performLivePreflightAction(.openOverlays))
        XCTAssertEqual(viewModel.livePreflightSnapshot, beforeSnapshot)
    }

    func testPlainTextReportContainsVersionAndNoPrivatePaths() {
        let viewModel = makeViewModel()
        viewModel.externalScreenProvider = { nil }
        viewModel.startTicker(text: "Welcome")

        let report = viewModel.livePreflightReportText()

        XCTAssertTrue(report.contains("LiveSwitcher Preflight v0.4.0"))
        XCTAssertTrue(report.contains("Overall: FAIL"))
        XCTAssertTrue(report.contains("Display"))
        XCTAssertTrue(report.contains("Action: 需要硬件"))
        XCTAssertTrue(report.contains("Action: 清空叠层"))
        XCTAssertFalse(report.localizedStandardContains("/Users/" + "liuchangxi"))
        XCTAssertFalse(report.localizedStandardContains("Ditu" + "LiveSwitcher"))
        XCTAssertFalse(report.localizedStandardContains("com." + "didu"))
    }

    func testDiagnosticsReportContainsRuntimeSummaryAndAllPreflightStatuses() {
        var preflight = readySnapshot()
        preflight.hasExternalDisplay = false
        preflight.isBroadcasting = false
        preflight.isSpeakerMode = true
        preflight.isPanicMode = true
        preflight.isBGMAudioTakeoverActive = true
        preflight.activeOverlayCount = 2
        preflight.autoPlayNextVideoOnEnd = true

        let checks = LivePreflightCheck.build(from: preflight)
        let diagnostics = LiveDiagnosticsSnapshot(
            appVersion: "0.4.0",
            operatingSystem: "macOS Test",
            architecture: "arm64-test",
            preflight: preflight
        )

        let report = LiveDiagnosticsReport.makePlainText(snapshot: diagnostics, checks: checks)

        XCTAssertTrue(report.contains("LiveSwitcher Diagnostics v0.4.0"))
        XCTAssertTrue(report.contains("Runtime: macOS Test, arm64-test"))
        XCTAssertTrue(report.contains("Overall: FAIL"))
        XCTAssertTrue(report.contains("Programs: 1"))
        XCTAssertTrue(report.contains("BGM tracks: 1"))
        XCTAssertTrue(report.contains("Wallpapers: 1"))
        XCTAssertTrue(report.contains("Active overlays: 2"))
        XCTAssertTrue(report.contains("Speaker mode: on"))
        XCTAssertTrue(report.contains("紧急切黑: on"))
        XCTAssertTrue(report.contains("BGM takeover: active"))
        XCTAssertTrue(report.contains("Auto-next video: on"))
        XCTAssertTrue(report.contains("- FAIL 外接显示器"))
        XCTAssertTrue(report.contains("- FAIL 紧急切黑"))
    }

    func testDiagnosticsReportRedactsRawPathsAndMediaNames() {
        var preflight = readySnapshot()
        preflight.currentProgramTitle = "/Users/" + "liuchangxi/Secret/Customer Dinner Video.mov"
        preflight.currentProgramSource = "Media"

        let checks = LivePreflightCheck.build(from: preflight)
        let diagnostics = LiveDiagnosticsSnapshot(
            appVersion: "0.4.0",
            operatingSystem: "macOS Test",
            architecture: "arm64-test",
            preflight: preflight
        )

        let report = LiveDiagnosticsReport.makePlainText(snapshot: diagnostics, checks: checks)

        XCTAssertTrue(report.contains("Current program: selected"))
        XCTAssertFalse(report.localizedStandardContains("/Users/"))
        XCTAssertFalse(report.localizedStandardContains("file://"))
        XCTAssertFalse(report.localizedStandardContains("Customer Dinner Video.mov"))
        XCTAssertFalse(report.localizedStandardContains("liuchangxi"))
    }

    func testViewModelDiagnosticsReportReflectsCurrentStateWithoutMutatingPlayback() {
        let viewModel = makeViewModel()
        viewModel.externalScreenProvider = { nil }
        viewModel.isPanicMode = true
        viewModel.isSpeakerMode = true
        viewModel.startTicker(text: "Welcome")
        let beforeSnapshot = viewModel.livePreflightSnapshot

        let report = viewModel.liveDiagnosticsReportText()

        XCTAssertTrue(report.contains("LiveSwitcher Diagnostics v0.4.0"))
        XCTAssertTrue(report.contains("Overall: FAIL"))
        XCTAssertTrue(report.contains("紧急切黑: on"))
        XCTAssertTrue(report.contains("Speaker mode: on"))
        XCTAssertTrue(report.contains("Active overlays: 1"))
        XCTAssertEqual(viewModel.livePreflightSnapshot, beforeSnapshot)
    }

    func testSupportReportContainsDiagnosticsPreflightEventsAndPrivacyNotice() {
        var preflight = readySnapshot()
        preflight.hasExternalDisplay = false
        preflight.isBroadcasting = false
        preflight.isPanicMode = true
        preflight.currentProgramTitle = "Customer Dinner Video.mov"

        let checks = LivePreflightCheck.build(from: preflight)
        let diagnostics = LiveDiagnosticsSnapshot(
            appVersion: "0.4.0",
            operatingSystem: "macOS Test",
            architecture: "arm64-test",
            preflight: preflight
        )
        let generatedAt = Date(timeIntervalSince1970: 1_790_000_000)
        let event = LiveSupportEvent(
            timestamp: generatedAt,
            kind: .preflightAction,
            detail: "manualReview file:///Users/" + "liuchangxi/Secret/Customer Dinner Video.mov"
        )

        let report = LiveSupportReport.makePlainText(
            snapshot: diagnostics,
            checks: checks,
            events: [event],
            generatedAt: generatedAt
        )

        XCTAssertTrue(report.contains("LiveSwitcher Support Report v0.4.0"))
        XCTAssertTrue(report.contains("Generated: 2026-09-21T14:13:20Z"))
        XCTAssertTrue(report.contains("[Diagnostics]"))
        XCTAssertTrue(report.contains("LiveSwitcher Diagnostics v0.4.0"))
        XCTAssertTrue(report.contains("[Preflight Report]"))
        XCTAssertTrue(report.contains("LiveSwitcher Preflight v0.4.0"))
        XCTAssertTrue(report.contains("[Recent Events]"))
        XCTAssertTrue(report.contains("preflight.action"))
        XCTAssertTrue(report.contains("[Privacy Notice]"))
        XCTAssertFalse(report.localizedStandardContains("/Users/"))
        XCTAssertFalse(report.localizedStandardContains("file://"))
        XCTAssertFalse(report.localizedStandardContains("Customer Dinner Video.mov"))
        XCTAssertFalse(report.localizedStandardContains("liuchangxi"))
    }

    func testSupportReportRedactsSensitiveEventDetailWithoutCollapsingWholeReport() {
        let preflight = readySnapshot()
        let checks = LivePreflightCheck.build(from: preflight)
        let diagnostics = LiveDiagnosticsSnapshot(
            appVersion: "0.4.0",
            operatingSystem: "macOS Test",
            architecture: "arm64-test",
            preflight: preflight
        )
        let generatedAt = Date(timeIntervalSince1970: 1_790_000_000)
        let event = LiveSupportEvent(
            timestamp: generatedAt,
            kind: .projectionFailClosed,
            detail: "blocked file:///Users/" + "liuchangxi/Show/Opening.mov"
        )

        let report = LiveSupportReport.makePlainText(
            snapshot: diagnostics,
            checks: checks,
            events: [event],
            generatedAt: generatedAt
        )

        XCTAssertTrue(report.contains("LiveSwitcher Support Report v0.4.0"))
        XCTAssertTrue(report.contains("[Diagnostics]"))
        XCTAssertTrue(report.contains("[Preflight Report]"))
        XCTAssertTrue(report.contains("[Recent Events]"))
        XCTAssertTrue(report.contains("projection.fail.closed"))
        XCTAssertTrue(report.contains("blocked [path redacted]"))
        XCTAssertFalse(report.localizedStandardContains("/Users/"))
        XCTAssertFalse(report.localizedStandardContains("file://"))
        XCTAssertFalse(report.localizedStandardContains("Opening.mov"))
        XCTAssertNotEqual(report, "[sensitive detail redacted]")
    }

    func testSupportReportRedactsFilenameOnlyMediaAndPresentationTokens() {
        let preflight = readySnapshot()
        let checks = LivePreflightCheck.build(from: preflight)
        let diagnostics = LiveDiagnosticsSnapshot(
            appVersion: "0.4.0",
            operatingSystem: "macOS Test",
            architecture: "arm64-test",
            preflight: preflight
        )
        let generatedAt = Date(timeIntervalSince1970: 1_790_000_000)
        let event = LiveSupportEvent(
            timestamp: generatedAt,
            kind: .bgmTakeoverChanged,
            detail: "media Opening.mov, audio walk-in.mp3, slides deck.key and product.pptx"
        )

        let report = LiveSupportReport.makePlainText(
            snapshot: diagnostics,
            checks: checks,
            events: [event],
            generatedAt: generatedAt
        )

        XCTAssertTrue(report.contains("LiveSwitcher Support Report v0.4.0"))
        XCTAssertTrue(report.contains("bgm.takeover.changed"))
        XCTAssertTrue(report.contains("[filename redacted]"))
        XCTAssertFalse(report.localizedStandardContains("Opening.mov"))
        XCTAssertFalse(report.localizedStandardContains("walk-in.mp3"))
        XCTAssertFalse(report.localizedStandardContains("deck.key"))
        XCTAssertFalse(report.localizedStandardContains("product.pptx"))
    }

    func testSupportEventTimelineCapsAtEightyEntriesAndDropsOldest() {
        let viewModel = makeViewModel()
        let start = Date(timeIntervalSince1970: 1_790_000_000)

        for index in 0..<85 {
            viewModel.recordSupportEvent(
                kind: .preflightAction,
                detail: "event \(index)",
                timestamp: start.addingTimeInterval(TimeInterval(index))
            )
        }

        XCTAssertEqual(viewModel.supportEvents.count, 80)
        XCTAssertEqual(viewModel.supportEvents.first?.detail, "event 5")
        XCTAssertEqual(viewModel.supportEvents.last?.detail, "event 84")
    }

    func testHighSignalActionsAppendSanitizedSupportEvents() {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0

        viewModel.toggleSpeakerMode()
        viewModel.togglePanicMode()
        viewModel.toggleBGM(BGMItem(title: "Walk-in", url: URL(fileURLWithPath: "/tmp/missing.mp3")))
        viewModel.performLivePreflightAction(.manualReview)
        viewModel.externalScreenProvider = { nil }
        viewModel.handleBroadcastToggle()

        let kinds = viewModel.supportEvents.map(\.kind)
        XCTAssertTrue(kinds.contains(.speakerModeChanged))
        XCTAssertTrue(kinds.contains(.panicModeChanged))
        XCTAssertTrue(kinds.contains(.bgmPlaybackChanged))
        XCTAssertFalse(kinds.contains(.bgmTakeoverChanged))
        XCTAssertTrue(kinds.contains(.preflightAction))
        XCTAssertTrue(kinds.contains(.projectionFailClosed))
        XCTAssertFalse(viewModel.supportEvents.contains { $0.detail.localizedStandardContains("/tmp/missing.mp3") })
    }

    func testViewModelSupportReportReflectsCurrentStateWithoutMutatingPlayback() {
        let viewModel = makeViewModel()
        viewModel.externalScreenProvider = { nil }
        viewModel.isPanicMode = true
        viewModel.isSpeakerMode = true
        viewModel.startTicker(text: "Customer ticker text")
        let beforeSnapshot = viewModel.livePreflightSnapshot
        let beforeProgramCount = viewModel.programItems.count
        let beforeBGMCount = viewModel.bgmItems.count
        let beforeWallpaperCount = viewModel.backgroundWallpapers.count

        let report = viewModel.liveSupportReportText(
            generatedAt: Date(timeIntervalSince1970: 1_790_000_000)
        )

        XCTAssertTrue(report.contains("LiveSwitcher Support Report v0.4.0"))
        XCTAssertTrue(report.contains("Overall: FAIL"))
        XCTAssertTrue(report.contains("紧急切黑: on"))
        XCTAssertTrue(report.contains("Speaker mode: on"))
        XCTAssertTrue(report.contains("Active overlays: 1"))
        XCTAssertFalse(report.localizedStandardContains("Customer ticker text"))
        XCTAssertEqual(viewModel.livePreflightSnapshot, beforeSnapshot)
        XCTAssertEqual(viewModel.programItems.count, beforeProgramCount)
        XCTAssertEqual(viewModel.bgmItems.count, beforeBGMCount)
        XCTAssertEqual(viewModel.backgroundWallpapers.count, beforeWallpaperCount)
    }

    func testViewModelSupportReportIncludesRuntimeActionTimeline() {
        let viewModel = makeViewModel()
        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        viewModel.togglePanicMode()

        let report = viewModel.liveSupportReportText(
            generatedAt: Date(timeIntervalSince1970: 1_790_000_000)
        )

        XCTAssertTrue(report.contains("[Recent Runtime Actions]"))
        XCTAssertTrue(report.contains("operatorSetPanic"))
        XCTAssertFalse(report.localizedStandardContains("/Users/"))
        XCTAssertFalse(report.localizedStandardContains("file://"))
    }

    func testSafetyCockpitOrdersFailWarnPassChecksForOperatorAttention() {
        var snapshot = readySnapshot()
        snapshot.hasExternalDisplay = false
        snapshot.isBroadcasting = false
        snapshot.autoPlayNextVideoOnEnd = true
        let checks = LivePreflightCheck.build(from: snapshot)

        let cockpit = LiveSafetyCockpit.make(
            snapshot: snapshot,
            checks: checks,
            events: []
        )

        XCTAssertEqual(cockpit.summary.status, .fail)
        XCTAssertEqual(cockpit.priorityChecks.first?.status, .fail)
        XCTAssertEqual(cockpit.priorityChecks.first?.id, "display.external")
        XCTAssertTrue(cockpit.priorityChecks.dropFirst().contains { $0.status == .warn })
        XCTAssertLessThan(
            cockpit.priorityChecks.firstIndex { $0.status == .warn } ?? Int.max,
            cockpit.priorityChecks.firstIndex { $0.status == .pass } ?? Int.max
        )
    }

    func testSafetyCockpitNoExternalDisplayCreatesNotReadyDisplayCard() {
        var snapshot = readySnapshot()
        snapshot.hasExternalDisplay = false
        snapshot.isBroadcasting = false
        let checks = LivePreflightCheck.build(from: snapshot)

        let cockpit = LiveSafetyCockpit.make(
            snapshot: snapshot,
            checks: checks,
            events: []
        )
        let displaySection = cockpit.sections.first { $0.group == .display }

        XCTAssertEqual(cockpit.summary.title, "未就绪")
        XCTAssertNotNil(displaySection)
        XCTAssertTrue(displaySection?.checks.contains { check in
            check.id == "display.external" &&
                check.status == .fail &&
                check.actionKind == .needsHardware
        } ?? false)
    }

    func testSafetyCockpitPanicAndOverlaysExposeOnlySafeMutatingActions() {
        var snapshot = readySnapshot()
        snapshot.isPanicMode = true
        snapshot.activeOverlayCount = 2
        let checks = LivePreflightCheck.build(from: snapshot)

        let cockpit = LiveSafetyCockpit.make(
            snapshot: snapshot,
            checks: checks,
            events: []
        )

        XCTAssertTrue(cockpit.priorityChecks.contains { $0.id == "controls.panic" && $0.actionKind == .turnOffPanic })
        XCTAssertTrue(cockpit.priorityChecks.contains { $0.id == "overlays.active" && $0.actionKind == .clearOverlays })
        XCTAssertFalse(cockpit.priorityChecks.contains { $0.actionKind == .needsHardware && ($0.actionKind?.isEnabledInPreflightUI ?? false) })
        XCTAssertTrue(cockpit.safeActionCount >= 2)
    }

    func testSafetyCockpitSanitizesRecentEventRows() {
        let snapshot = readySnapshot()
        let checks = LivePreflightCheck.build(from: snapshot)
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 1_790_000_000),
            kind: .projectionFailClosed,
            detail: "lost file:///Users/" + "liuchangxi/Show/Opening.mov"
        )

        let cockpit = LiveSafetyCockpit.make(
            snapshot: snapshot,
            checks: checks,
            events: [event]
        )

        XCTAssertEqual(cockpit.recentEvents.count, 1)
        XCTAssertEqual(cockpit.recentEvents[0].kind, "projection.fail.closed")
        XCTAssertEqual(cockpit.recentEvents[0].detail, "lost [path redacted]")
        XCTAssertFalse(cockpit.recentEvents[0].detail.localizedStandardContains("/Users/"))
        XCTAssertFalse(cockpit.recentEvents[0].detail.localizedStandardContains("Opening.mov"))
    }

    func testSafetyCockpitRecentEventRowsUseUniqueIDsForRepeatedSameKindEventsInSameSecond() {
        let snapshot = readySnapshot()
        let checks = LivePreflightCheck.build(from: snapshot)
        let timestamp = Date(timeIntervalSince1970: 1_790_000_000)
        let events = [
            LiveSupportEvent(timestamp: timestamp, kind: .preflightAction, detail: "clearOverlays"),
            LiveSupportEvent(timestamp: timestamp, kind: .preflightAction, detail: "turnOffPanic")
        ]

        let cockpit = LiveSafetyCockpit.make(
            snapshot: snapshot,
            checks: checks,
            events: events
        )

        XCTAssertEqual(cockpit.recentEvents.count, 2)
        XCTAssertEqual(Set(cockpit.recentEvents.map(\.id)).count, 2)
        XCTAssertEqual(cockpit.recentEvents[0].timestamp, cockpit.recentEvents[1].timestamp)
        XCTAssertEqual(cockpit.recentEvents[0].kind, cockpit.recentEvents[1].kind)
    }

    func testSafetyCockpitRecentEventRowsKeepLatestTwelveRows() {
        let snapshot = readySnapshot()
        let checks = LivePreflightCheck.build(from: snapshot)
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        let events = (0..<14).map { index in
            LiveSupportEvent(
                timestamp: start.addingTimeInterval(TimeInterval(index)),
                kind: .preflightAction,
                detail: "event \(index)"
            )
        }

        let cockpit = LiveSafetyCockpit.make(
            snapshot: snapshot,
            checks: checks,
            events: events
        )

        XCTAssertEqual(cockpit.recentEvents.count, 12)
        XCTAssertEqual(cockpit.recentEvents.first?.detail, "event 2")
        XCTAssertEqual(cockpit.recentEvents.last?.detail, "event 13")
    }

    func testSafetyCockpitRecentEventIDsStayStableWhenCappedTimelineAdvances() {
        let snapshot = readySnapshot()
        let checks = LivePreflightCheck.build(from: snapshot)
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        let firstBatch = (0..<12).map { index in
            LiveSupportEvent(
                timestamp: start.addingTimeInterval(TimeInterval(index)),
                kind: .preflightAction,
                detail: "event \(index)"
            )
        }
        let secondBatch = firstBatch + [
            LiveSupportEvent(
                timestamp: start.addingTimeInterval(12),
                kind: .preflightAction,
                detail: "event 12"
            )
        ]

        let firstCockpit = LiveSafetyCockpit.make(
            snapshot: snapshot,
            checks: checks,
            events: firstBatch
        )
        let secondCockpit = LiveSafetyCockpit.make(
            snapshot: snapshot,
            checks: checks,
            events: secondBatch
        )

        let firstEventOneID = firstCockpit.recentEvents.first { $0.detail == "event 1" }?.id
        let secondEventOneID = secondCockpit.recentEvents.first { $0.detail == "event 1" }?.id

        XCTAssertNotNil(firstEventOneID)
        XCTAssertEqual(firstEventOneID, secondEventOneID)
    }

    func testPreflightNavigationActionsMapToMainConsoleTabs() {
        XCTAssertEqual(LivePreflightActionKind.openPreview.mainConsoleDestination, .preview)
        XCTAssertEqual(LivePreflightActionKind.openAudioMixer.mainConsoleDestination, .audioMixer)
        XCTAssertEqual(LivePreflightActionKind.openOverlays.mainConsoleDestination, .overlays)
    }

    func testSafeMutatingAndManualPreflightActionsDoNotMapToMainConsoleTabs() {
        XCTAssertNil(LivePreflightActionKind.clearOverlays.mainConsoleDestination)
        XCTAssertNil(LivePreflightActionKind.turnOffPanic.mainConsoleDestination)
        XCTAssertNil(LivePreflightActionKind.needsHardware.mainConsoleDestination)
        XCTAssertNil(LivePreflightActionKind.manualReview.mainConsoleDestination)
    }

    func testPreflightActionPresentationSeparatesButtonsFromGuidance() {
        XCTAssertEqual(LivePreflightActionKind.clearOverlays.presentationRole, .safeOneClick)
        XCTAssertEqual(LivePreflightActionKind.turnOffPanic.presentationRole, .safeOneClick)
        XCTAssertEqual(LivePreflightActionKind.openPreview.presentationRole, .navigation)
        XCTAssertEqual(LivePreflightActionKind.openAudioMixer.presentationRole, .navigation)
        XCTAssertEqual(LivePreflightActionKind.openOverlays.presentationRole, .navigation)
        XCTAssertEqual(LivePreflightActionKind.needsHardware.presentationRole, .operatorGuidance)
        XCTAssertEqual(LivePreflightActionKind.manualReview.presentationRole, .operatorGuidance)

        XCTAssertTrue(LivePreflightActionKind.clearOverlays.shouldRenderAsButton)
        XCTAssertTrue(LivePreflightActionKind.openPreview.shouldRenderAsButton)
        XCTAssertFalse(LivePreflightActionKind.needsHardware.shouldRenderAsButton)
        XCTAssertFalse(LivePreflightActionKind.manualReview.shouldRenderAsButton)
    }
}
