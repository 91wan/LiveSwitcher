import XCTest
@testable import LiveSwitcher

@MainActor
final class LivePreflightRiskTests: XCTestCase {
    func testPanicModeActiveIsClearlyReportedAsEmergencyState() {
        let viewModel = makeLivePreflightTestViewModel()
        viewModel.dispatchRuntimeFacadeAction(.operatorSetPanic(true))

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let panic = livePreflightCheck("controls.panic", in: checks)

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
        let viewModel = makeLivePreflightTestViewModel()
        viewModel.isSpeakerMode = true

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let speaker = livePreflightCheck("audio.speaker", in: checks)

        XCTAssertEqual(speaker.group, .audio)
        XCTAssertEqual(speaker.status, .warn)
        XCTAssertTrue(speaker.message.localizedStandardContains("媒体和 BGM 压低已开启"))
    }

    func testBGMTakeoverReportsMediaAudioMutedByTakeover() {
        let viewModel = makeLivePreflightTestViewModel()
        viewModel.bgmItems = [
            BGMItem(title: "Walk-in Music", url: URL(fileURLWithPath: "/tmp/walk-in.mp3"), category: .warmUp)
        ]
        viewModel.isBGMPlaying = true
        viewModel.isBGMAudioTakeoverActive = true

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let takeover = livePreflightCheck("audio.bgm-takeover", in: checks)

        XCTAssertEqual(takeover.group, .audio)
        XCTAssertEqual(takeover.status, .warn)
        XCTAssertEqual(takeover.actionKind, .openAudioMixer)
        XCTAssertEqual(takeover.actionLabel, "打开音频页")
        XCTAssertTrue(takeover.message.localizedStandardContains("媒体声道被 BGM 接管静音"))
    }

    func testNoBGMItemsWarnsAudioReadiness() {
        let viewModel = makeLivePreflightTestViewModel()
        viewModel.bgmItems = []

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let bgm = livePreflightCheck("audio.bgm-library", in: checks)

        XCTAssertEqual(bgm.group, .audio)
        XCTAssertEqual(bgm.status, .warn)
        XCTAssertEqual(bgm.actionKind, .openAudioMixer)
        XCTAssertEqual(bgm.actionLabel, "打开音频页")
        XCTAssertTrue(bgm.message.localizedStandardContains("未载入 BGM 曲目"))
    }

    func testNoWallpaperWarnsPlaybackFallbackReadiness() {
        let viewModel = makeLivePreflightTestViewModel()
        viewModel.backgroundWallpapers = []

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let wallpaper = livePreflightCheck("playback.wallpaper", in: checks)

        XCTAssertEqual(wallpaper.group, .playback)
        XCTAssertEqual(wallpaper.status, .warn)
        XCTAssertEqual(wallpaper.actionKind, .openPreview)
        XCTAssertEqual(wallpaper.actionLabel, "打开节目单")
        XCTAssertTrue(wallpaper.message.localizedStandardContains("尚未载入待机壁纸"))
    }

    func testActiveOverlaysReportOverlayCount() {
        let viewModel = makeLivePreflightTestViewModel()
        viewModel.startCountdown(seconds: 30, title: "Start")
        viewModel.startTicker(text: "Welcome")
        viewModel.showLowerThird(name: "Host", role: "", organization: "Opening")

        let snapshot = viewModel.livePreflightSnapshot
        XCTAssertEqual(snapshot.activeOverlayCount, 3)
        XCTAssertEqual(snapshot.activeOverlayKinds, [.countdown, .ticker, .lowerThird])
        XCTAssertEqual(snapshot.countdownRemainingSeconds, 30)

        let checks = LivePreflightCheck.build(from: snapshot)
        let overlays = livePreflightCheck("overlays.active", in: checks)

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
        XCTAssertEqual(viewModel.lowerThirdRole, "")
        XCTAssertEqual(viewModel.lowerThirdOrganization, "")
    }

    func testOverlayReportsDoNotLeakOverlayContent() {
        let viewModel = makeLivePreflightTestViewModel()
        viewModel.startCountdown(seconds: 45, title: "Private Show Title")
        viewModel.startTicker(text: "Customer ticker text")
        viewModel.showLowerThird(name: "Private Host", role: "Private Role", organization: "Private Company")

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
        let viewModel = makeLivePreflightTestViewModel()
        viewModel.autoPlayNextVideoOnEnd = true

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let autoNext = livePreflightCheck("playback.auto-next", in: checks)

        XCTAssertEqual(autoNext.group, .playback)
        XCTAssertEqual(autoNext.status, .warn)
        XCTAssertEqual(autoNext.actionKind, .openPreview)
        XCTAssertEqual(autoNext.actionLabel, "打开节目单")
    }

    func testSafetyCockpitPanicAndOverlaysExposeOnlySafeMutatingActions() {
        var snapshot = livePreflightReadySnapshot()
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
}
