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
            appVersion: "0.3.0",
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

        XCTAssertTrue(report.contains("LiveSwitcher Preflight v0.3.0"))
        XCTAssertTrue(report.contains("Overall: FAIL"))
        XCTAssertTrue(report.contains("Display"))
        XCTAssertTrue(report.contains("Action: Needs hardware"))
        XCTAssertTrue(report.contains("Action: Clear overlays"))
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
            appVersion: "0.3.0",
            operatingSystem: "macOS Test",
            architecture: "arm64-test",
            preflight: preflight
        )

        let report = LiveDiagnosticsReport.makePlainText(snapshot: diagnostics, checks: checks)

        XCTAssertTrue(report.contains("LiveSwitcher Diagnostics v0.3.0"))
        XCTAssertTrue(report.contains("Runtime: macOS Test, arm64-test"))
        XCTAssertTrue(report.contains("Overall: FAIL"))
        XCTAssertTrue(report.contains("Programs: 1"))
        XCTAssertTrue(report.contains("BGM tracks: 1"))
        XCTAssertTrue(report.contains("Wallpapers: 1"))
        XCTAssertTrue(report.contains("Active overlays: 2"))
        XCTAssertTrue(report.contains("Speaker mode: on"))
        XCTAssertTrue(report.contains("Panic blackout: on"))
        XCTAssertTrue(report.contains("BGM takeover: active"))
        XCTAssertTrue(report.contains("Auto-next video: on"))
        XCTAssertTrue(report.contains("- FAIL External Display"))
        XCTAssertTrue(report.contains("- FAIL Panic Blackout"))
    }

    func testDiagnosticsReportRedactsRawPathsAndMediaNames() {
        var preflight = readySnapshot()
        preflight.currentProgramTitle = "/Users/" + "liuchangxi/Secret/Customer Dinner Video.mov"
        preflight.currentProgramSource = "Media"

        let checks = LivePreflightCheck.build(from: preflight)
        let diagnostics = LiveDiagnosticsSnapshot(
            appVersion: "0.3.0",
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

        XCTAssertTrue(report.contains("LiveSwitcher Diagnostics v0.3.0"))
        XCTAssertTrue(report.contains("Overall: FAIL"))
        XCTAssertTrue(report.contains("Panic blackout: on"))
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
            appVersion: "0.3.0",
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

        XCTAssertTrue(report.contains("LiveSwitcher Support Report v0.3.0"))
        XCTAssertTrue(report.contains("Generated: 2026-09-21T14:13:20Z"))
        XCTAssertTrue(report.contains("[Diagnostics]"))
        XCTAssertTrue(report.contains("LiveSwitcher Diagnostics v0.3.0"))
        XCTAssertTrue(report.contains("[Preflight Report]"))
        XCTAssertTrue(report.contains("LiveSwitcher Preflight v0.3.0"))
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
            appVersion: "0.3.0",
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

        XCTAssertTrue(report.contains("LiveSwitcher Support Report v0.3.0"))
        XCTAssertTrue(report.contains("[Diagnostics]"))
        XCTAssertTrue(report.contains("[Preflight Report]"))
        XCTAssertTrue(report.contains("[Recent Events]"))
        XCTAssertTrue(report.contains("projection.fail.closed"))
        XCTAssertTrue(report.contains("[sensitive detail redacted]"))
        XCTAssertFalse(report.localizedStandardContains("/Users/"))
        XCTAssertFalse(report.localizedStandardContains("file://"))
        XCTAssertFalse(report.localizedStandardContains("Opening.mov"))
        XCTAssertNotEqual(report, "[sensitive detail redacted]")
    }

    func testSupportReportRedactsFilenameOnlyMediaAndPresentationTokens() {
        let preflight = readySnapshot()
        let checks = LivePreflightCheck.build(from: preflight)
        let diagnostics = LiveDiagnosticsSnapshot(
            appVersion: "0.3.0",
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

        XCTAssertTrue(report.contains("LiveSwitcher Support Report v0.3.0"))
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
        viewModel.handleExternalDisplayLost()

        let kinds = viewModel.supportEvents.map(\.kind)
        XCTAssertTrue(kinds.contains(.speakerModeChanged))
        XCTAssertTrue(kinds.contains(.panicModeChanged))
        XCTAssertTrue(kinds.contains(.bgmTakeoverChanged))
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

        XCTAssertTrue(report.contains("LiveSwitcher Support Report v0.3.0"))
        XCTAssertTrue(report.contains("Overall: FAIL"))
        XCTAssertTrue(report.contains("Panic blackout: on"))
        XCTAssertTrue(report.contains("Speaker mode: on"))
        XCTAssertTrue(report.contains("Active overlays: 1"))
        XCTAssertFalse(report.localizedStandardContains("Customer ticker text"))
        XCTAssertEqual(viewModel.livePreflightSnapshot, beforeSnapshot)
        XCTAssertEqual(viewModel.programItems.count, beforeProgramCount)
        XCTAssertEqual(viewModel.bgmItems.count, beforeBGMCount)
        XCTAssertEqual(viewModel.backgroundWallpapers.count, beforeWallpaperCount)
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

        XCTAssertEqual(cockpit.summary.title, "Not ready")
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
        XCTAssertEqual(cockpit.recentEvents[0].detail, "[sensitive detail redacted]")
        XCTAssertFalse(cockpit.recentEvents[0].detail.localizedStandardContains("/Users/"))
        XCTAssertFalse(cockpit.recentEvents[0].detail.localizedStandardContains("Opening.mov"))
    }
}
