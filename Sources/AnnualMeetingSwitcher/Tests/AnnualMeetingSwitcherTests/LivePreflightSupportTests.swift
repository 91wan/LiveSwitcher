import XCTest
@testable import LiveSwitcher

@MainActor
final class LivePreflightLiveSupportReportTests: XCTestCase {
    func testPlainTextReportContainsVersionAndNoPrivatePaths() {
        let viewModel = makeLivePreflightTestViewModel()
        viewModel.externalScreenProvider = { nil }
        viewModel.startTicker(text: "Welcome")
        let expectedVersion = AppConfiguration.appVersion

        let report = viewModel.livePreflightReportText()

        XCTAssertTrue(report.contains("LiveSwitcher Preflight v\(expectedVersion)"))
        XCTAssertTrue(report.contains("Overall: FAIL"))
        XCTAssertTrue(report.contains("Display"))
        XCTAssertTrue(report.contains("Action: 需要硬件"))
        XCTAssertTrue(report.contains("Action: 清空叠层"))
        XCTAssertFalse(report.localizedStandardContains("/Users/" + "liuchangxi"))
        XCTAssertFalse(report.localizedStandardContains("Ditu" + "LiveSwitcher"))
        XCTAssertFalse(report.localizedStandardContains("com." + "didu"))
    }

    func testDiagnosticsReportContainsRuntimeSummaryAndAllPreflightStatuses() {
        var preflight = livePreflightReadySnapshot()
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
        var preflight = livePreflightReadySnapshot()
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
        let viewModel = makeLivePreflightTestViewModel()
        viewModel.externalScreenProvider = { nil }
        viewModel.applyPanicProjectionFromRuntime(isActive: true, snapshot: nil)
        viewModel.isSpeakerMode = true
        viewModel.startTicker(text: "Welcome")
        let beforeSnapshot = viewModel.livePreflightSnapshot
        let expectedVersion = AppConfiguration.appVersion

        let report = viewModel.liveDiagnosticsReportText()

        XCTAssertTrue(report.contains("LiveSwitcher Diagnostics v\(expectedVersion)"))
        XCTAssertTrue(report.contains("Overall: FAIL"))
        XCTAssertTrue(report.contains("紧急切黑: on"))
        XCTAssertTrue(report.contains("Speaker mode: on"))
        XCTAssertTrue(report.contains("Active overlays: 1"))
        XCTAssertEqual(viewModel.livePreflightSnapshot, beforeSnapshot)
    }

    func testSupportReportContainsDiagnosticsPreflightEventsAndPrivacyNotice() {
        var preflight = livePreflightReadySnapshot()
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
        let preflight = livePreflightReadySnapshot()
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
        let preflight = livePreflightReadySnapshot()
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
        let viewModel = makeLivePreflightTestViewModel()
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
        let viewModel = makeLivePreflightTestViewModel()
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
        let viewModel = makeLivePreflightTestViewModel()
        viewModel.externalScreenProvider = { nil }
        viewModel.applyPanicProjectionFromRuntime(isActive: true, snapshot: nil)
        viewModel.isSpeakerMode = true
        viewModel.startTicker(text: "Customer ticker text")
        let beforeSnapshot = viewModel.livePreflightSnapshot
        let beforeProgramCount = viewModel.programItems.count
        let beforeBGMCount = viewModel.bgmItems.count
        let beforeWallpaperCount = viewModel.backgroundWallpapers.count
        let expectedVersion = AppConfiguration.appVersion

        let report = viewModel.liveSupportReportText(
            generatedAt: Date(timeIntervalSince1970: 1_790_000_000)
        )

        XCTAssertTrue(report.contains("LiveSwitcher Support Report v\(expectedVersion)"))
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
        let viewModel = makeLivePreflightTestViewModel()
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

    func testSafetyCockpitSanitizesRecentEventRows() {
        let snapshot = livePreflightReadySnapshot()
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
        let snapshot = livePreflightReadySnapshot()
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
        let snapshot = livePreflightReadySnapshot()
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
        let snapshot = livePreflightReadySnapshot()
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
}
