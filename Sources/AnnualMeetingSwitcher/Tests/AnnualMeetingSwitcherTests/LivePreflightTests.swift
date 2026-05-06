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
            appVersion: "0.2.6",
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
        XCTAssertEqual(display.actionLabel, "Needs hardware")
        XCTAssertTrue(display.message.localizedStandardContains("Needs hardware"))
        XCTAssertTrue(display.message.localizedStandardContains("Do not project"))

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
        XCTAssertEqual(summary.title, "Not ready")
        XCTAssertEqual(summary.failCount, 1)
        XCTAssertGreaterThan(summary.warnCount, 0)
    }

    func testSummaryWarnsWhenChecksHaveWarningsButNoFailures() {
        var snapshot = readySnapshot()
        snapshot.autoPlayNextVideoOnEnd = true

        let summary = LivePreflightSummary.make(from: LivePreflightCheck.build(from: snapshot))

        XCTAssertEqual(summary.status, .warn)
        XCTAssertEqual(summary.title, "Needs review")
        XCTAssertEqual(summary.failCount, 0)
        XCTAssertGreaterThan(summary.warnCount, 0)
    }

    func testSummaryPassesWhenAllChecksPass() {
        let summary = LivePreflightSummary.make(from: LivePreflightCheck.build(from: readySnapshot()))

        XCTAssertEqual(summary.status, .pass)
        XCTAssertEqual(summary.title, "Ready")
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
        XCTAssertTrue(display.message.localizedStandardContains("External display detected"))
    }

    func testPanicModeActiveIsClearlyReportedAsEmergencyState() {
        let viewModel = makeViewModel()
        viewModel.isPanicMode = true

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let panic = check("controls.panic", in: checks)

        XCTAssertEqual(panic.group, .controls)
        XCTAssertEqual(panic.status, .fail)
        XCTAssertEqual(panic.actionKind, .turnOffPanic)
        XCTAssertEqual(panic.actionLabel, "Turn off panic")
        XCTAssertTrue(panic.message.localizedStandardContains("Panic blackout is active"))

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
        XCTAssertTrue(speaker.message.localizedStandardContains("Media and BGM ducking is active"))
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
        XCTAssertEqual(takeover.actionLabel, "Open audio mixer")
        XCTAssertTrue(takeover.message.localizedStandardContains("Media audio is muted by BGM takeover"))
    }

    func testNoBGMItemsWarnsAudioReadiness() {
        let viewModel = makeViewModel()
        viewModel.bgmItems = []

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let bgm = check("audio.bgm-library", in: checks)

        XCTAssertEqual(bgm.group, .audio)
        XCTAssertEqual(bgm.status, .warn)
        XCTAssertEqual(bgm.actionKind, .openAudioMixer)
        XCTAssertEqual(bgm.actionLabel, "Open audio mixer")
        XCTAssertTrue(bgm.message.localizedStandardContains("No BGM tracks loaded"))
    }

    func testNoWallpaperWarnsPlaybackFallbackReadiness() {
        let viewModel = makeViewModel()
        viewModel.backgroundWallpapers = []

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let wallpaper = check("playback.wallpaper", in: checks)

        XCTAssertEqual(wallpaper.group, .playback)
        XCTAssertEqual(wallpaper.status, .warn)
        XCTAssertEqual(wallpaper.actionKind, .openPreview)
        XCTAssertEqual(wallpaper.actionLabel, "Open preview")
        XCTAssertTrue(wallpaper.message.localizedStandardContains("No wallpaper fallback"))
    }

    func testActiveOverlaysReportOverlayCount() {
        let viewModel = makeViewModel()
        viewModel.startCountdown(seconds: 30, title: "Start")
        viewModel.startTicker(text: "Welcome")
        viewModel.showLowerThird(name: "Host", title: "Opening")

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let overlays = check("overlays.active", in: checks)

        XCTAssertEqual(overlays.group, .overlays)
        XCTAssertEqual(overlays.status, .warn)
        XCTAssertEqual(overlays.actionKind, .clearOverlays)
        XCTAssertEqual(overlays.actionLabel, "Clear overlays")
        XCTAssertTrue(overlays.message.localizedStandardContains("3 overlays active"))

        let attentionChecks = LivePreflightCheck.attentionChecks(from: checks)
        XCTAssertTrue(attentionChecks.contains(overlays))

        XCTAssertTrue(viewModel.performLivePreflightAction(.clearOverlays))
        XCTAssertFalse(viewModel.isCountdownActive)
        XCTAssertFalse(viewModel.isTickerActive)
        XCTAssertFalse(viewModel.isLowerThirdVisible)
        XCTAssertEqual(viewModel.lowerThirdName, "")
        XCTAssertEqual(viewModel.lowerThirdTitle, "")
    }

    func testAutoNextWarningRecommendsPreviewReview() {
        let viewModel = makeViewModel()
        viewModel.autoPlayNextVideoOnEnd = true

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let autoNext = check("playback.auto-next", in: checks)

        XCTAssertEqual(autoNext.group, .playback)
        XCTAssertEqual(autoNext.status, .warn)
        XCTAssertEqual(autoNext.actionKind, .openPreview)
        XCTAssertEqual(autoNext.actionLabel, "Open preview")
    }

    func testPPTModeUsesManualReviewActionWithoutMutatingState() {
        let viewModel = makeViewModel()
        viewModel.isPageInterceptEnabled = true

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let ppt = check("controls.ppt", in: checks)

        XCTAssertEqual(ppt.group, .controls)
        XCTAssertEqual(ppt.status, .pass)
        XCTAssertEqual(ppt.actionKind, .manualReview)
        XCTAssertEqual(ppt.actionLabel, "Manual review")

        let beforeSnapshot = viewModel.livePreflightSnapshot
        XCTAssertFalse(viewModel.performLivePreflightAction(.manualReview))
        XCTAssertEqual(viewModel.livePreflightSnapshot, beforeSnapshot)
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

        XCTAssertTrue(report.contains("LiveSwitcher Preflight v0.2.6"))
        XCTAssertTrue(report.contains("Overall: FAIL"))
        XCTAssertTrue(report.contains("Display"))
        XCTAssertTrue(report.contains("Action: Needs hardware"))
        XCTAssertTrue(report.contains("Action: Clear overlays"))
        XCTAssertFalse(report.localizedStandardContains("/Users/" + "liuchangxi"))
        XCTAssertFalse(report.localizedStandardContains("Ditu" + "LiveSwitcher"))
        XCTAssertFalse(report.localizedStandardContains("com." + "didu"))
    }
}
