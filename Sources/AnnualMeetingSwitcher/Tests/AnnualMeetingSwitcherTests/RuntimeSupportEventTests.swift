import AppKit
import SwiftUI
import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeSupportEventTests: XCTestCase {
    private final class OutputWindowControllerSpy: OutputWindowControlling {
        var onExternalDisplayUnavailable: (() -> Void)?
        private(set) var showCount = 0
        private(set) var hideCount = 0

        func mountAnyView(rootView: AnyView) {}

        func show(on screen: NSScreen?) {
            showCount += 1
        }

        func hide() {
            hideCount += 1
        }
    }

    func testBGMPlaybackFailureStopsTakeoverAndRecordsSanitizedEvent() {
        let viewModel = makeViewModel()
        let item = BGMItem(
            title: "Private Walk In",
            url: URL(fileURLWithPath: "/tmp/private-walk-in.mp3"),
            category: .warmUp
        )
        viewModel.bgmItems = [item]
        viewModel.currentBGMItem = item
        viewModel.isBGMPlaying = true
        viewModel.seedActiveRuntimeBGMCallbackForTesting(item: item, generation: 0)
        viewModel.isBGMAudioTakeoverActive = true
        viewModel.bgmProgress = 0.6
        viewModel.bgmCurrentTime = 42
        viewModel.bgmDuration = 100
        var runtimeState = viewModel.runtime.state
        runtimeState.bgm.items = [item]
        runtimeState.bgm.currentID = item.id
        runtimeState.bgm.phase = .playing
        runtimeState.bgm.progress = 0.6
        runtimeState.bgm.currentTime = 42
        runtimeState.bgm.duration = 100
        runtimeState.bgm.generation = 0
        viewModel.runtime.replaceStateForFacadeSync(runtimeState, clearActionLog: true)

        viewModel.bgmDidFail()

        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertFalse(viewModel.isBGMAudioTakeoverActive)
        XCTAssertEqual(viewModel.bgmProgress, 0.6)
        XCTAssertEqual(viewModel.bgmCurrentTime, 42)
        XCTAssertEqual(viewModel.bgmDuration, 100)
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .bgmPlaybackFailed })
        XCTAssertFalse(viewModel.supportEvents.contains { $0.detail.localizedStandardContains("Private Walk In") })
        XCTAssertFalse(viewModel.supportEvents.contains { $0.detail.localizedStandardContains("/tmp/private-walk-in.mp3") })
    }

    func testProjectionSupportEventsDistinguishStartStopFailAndLost() {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        viewModel.outputWindowControllerFactory = { outputSpy }

        viewModel.externalScreenProvider = { nil }
        viewModel.handleBroadcastToggle()
        viewModel.externalScreenProvider = { NSScreen.main ?? NSScreen.screens.first }
        viewModel.handleBroadcastToggle()
        viewModel.handleBroadcastToggle()
        viewModel.handleBroadcastToggle()
        viewModel.handleExternalDisplayLost()

        let kinds = viewModel.supportEvents.map(\.kind)
        XCTAssertTrue(kinds.contains(.projectionStartFailed))
        XCTAssertTrue(kinds.contains(.projectionStarted))
        XCTAssertTrue(kinds.contains(.projectionStopped))
        XCTAssertTrue(kinds.contains(.projectionLost))
        XCTAssertFalse(viewModel.supportEvents.contains { $0.detail.localizedStandardContains("/Users/") })
    }

    func testRepeatedAutomationFailuresCoalesceWithoutEvictingImportantEvents() {
        let viewModel = makeViewModel()
        viewModel.recordSupportEvent(kind: .projectionStarted, detail: "isBroadcasting=true")

        for _ in 0..<100 {
            viewModel.handleAppleScriptFailure(
                AppleScriptError.executionFailed(
                    action: "keynote.next-slide",
                    message: "presentation app did not accept next slide"
                ),
                action: "keynote.next-slide"
            )
        }

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionStarted })
        let failures = viewModel.supportEvents.filter { $0.kind == .appleScriptFailed }
        XCTAssertEqual(failures.count, 1)
        XCTAssertTrue(failures[0].detail.contains("action=keynote.next-slide"))
        XCTAssertTrue(failures[0].detail.contains("count=100"))
        XCTAssertTrue(failures[0].detail.contains("lastSeen="))
    }

    func testRepeatedAutomationFailuresWithChangingMessagesStaySeparateByMessage() {
        let viewModel = makeViewModel()
        viewModel.recordSupportEvent(kind: .projectionStarted, detail: "isBroadcasting=true")

        for index in 0..<3 {
            viewModel.handleAppleScriptFailure(
                AppleScriptError.executionFailed(
                    action: "keynote.next-slide",
                    message: "presentation app did not accept next slide attempt \(index)"
                ),
                action: "keynote.next-slide"
            )
        }

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionStarted })
        let failures = viewModel.supportEvents.filter { $0.kind == .appleScriptFailed }
        XCTAssertEqual(failures.count, 3)
        XCTAssertTrue(failures.allSatisfy { $0.detail.contains("action=keynote.next-slide") })
        XCTAssertFalse(failures.contains { $0.detail.contains("count=") })
    }

    func testRepeatedPageInterceptWPSMissingEventsCoalesceWithoutEvictingImportantEvents() {
        let viewModel = makeViewModel()
        viewModel.recordSupportEvent(kind: .projectionStarted, detail: "isBroadcasting=true")

        for _ in 0..<100 {
            viewModel.recordSupportEvent(
                kind: .pageInterceptWPSNotRunning,
                detail: "direction=next,state=notRunning"
            )
        }

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionStarted })
        let failures = viewModel.supportEvents.filter { $0.kind == .pageInterceptWPSNotRunning }
        XCTAssertEqual(failures.count, 1)
        XCTAssertTrue(failures[0].detail.contains("direction=next"))
        XCTAssertTrue(failures[0].detail.contains("count=100"))
        XCTAssertTrue(failures[0].detail.contains("lastSeen="))
    }

    func testRepeatedPageInterceptForwardedEventsCoalesceWithoutEvictingImportantEvents() {
        let viewModel = makeViewModel()
        viewModel.recordSupportEvent(kind: .projectionStarted, detail: "isBroadcasting=true")

        for _ in 0..<100 {
            viewModel.recordSupportEvent(
                kind: .pageInterceptForwardedToWPS,
                detail: "direction=next,target=wps"
            )
        }

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionStarted })
        let forwarded = viewModel.supportEvents.filter { $0.kind == .pageInterceptForwardedToWPS }
        XCTAssertEqual(forwarded.count, 1)
        XCTAssertTrue(forwarded[0].detail.contains("direction=next"))
        XCTAssertTrue(forwarded[0].detail.contains("count=100"))
        XCTAssertTrue(forwarded[0].detail.contains("lastSeen="))
    }

    func testViewModelSupportEventsDispatchRuntimeIngressWithoutActionLogNoiseAndMirrorFacadeState() {
        let viewModel = makeViewModel()

        viewModel.recordSupportEvent(
            kind: .projectionStarted,
            detail: "isBroadcasting=true",
            timestamp: Date(timeIntervalSince1970: 1_790_000_000)
        )

        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "supportEventRecorded" })
        XCTAssertEqual(viewModel.runtime.state.support.events, viewModel.supportEvents)
        XCTAssertEqual(viewModel.supportEvents.last?.kind, .projectionStarted)
    }

    func testSupportRuntimeCoalescingSurvivesFacadeSync() {
        let viewModel = makeViewModel()

        for index in 0..<3 {
            viewModel.recordSupportEvent(
                kind: .pageInterceptWPSNotRunning,
                detail: "direction=next,state=notRunning",
                timestamp: Date(timeIntervalSince1970: TimeInterval(1_790_000_000 + index))
            )
        }

        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "supportEventRecorded" })
        XCTAssertEqual(viewModel.runtime.state.support.events, viewModel.supportEvents)
        let event = try? XCTUnwrap(viewModel.supportEvents.last)
        XCTAssertEqual(event?.kind, .pageInterceptWPSNotRunning)
        XCTAssertTrue(event?.detail.contains("count=3") == true)
        XCTAssertTrue(event?.detail.contains("lastSeen=") == true)
    }

    func testSupportRuntimeKeepsNonCoalescedRepeatedEventsSeparate() {
        let viewModel = makeViewModel()

        viewModel.recordSupportEvent(kind: .preflightAction, detail: "action=manualReview")
        viewModel.recordSupportEvent(kind: .preflightAction, detail: "action=manualReview")

        XCTAssertEqual(viewModel.supportEvents.filter { $0.kind == .preflightAction }.count, 2)
        XCTAssertFalse(viewModel.supportEvents.contains { $0.detail.contains("count=") })
    }

    func testExternalDisplayLostIsIdempotentForSingleDisconnect() {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.externalScreenProvider = { NSScreen.main ?? NSScreen.screens.first }

        viewModel.handleBroadcastToggle()
        XCTAssertTrue(viewModel.isBroadcasting)

        viewModel.handleExternalDisplayLost()
        viewModel.handleExternalDisplayLost()

        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.hideCount, 1)
        XCTAssertEqual(viewModel.supportEvents.filter { $0.kind == .projectionLost }.count, 1)
        XCTAssertEqual(viewModel.supportEvents.filter { $0.kind == .projectionFailClosed }.count, 1)
    }

    func testOverlaySupportEventsDoNotRecordOperatorText() {
        let viewModel = makeViewModel()

        viewModel.startCountdown(seconds: 10, title: "Private countdown title")
        viewModel.stopCountdown()
        viewModel.startTicker(text: "Customer ticker text")
        viewModel.stopTicker()
        viewModel.showLowerThird(name: "Private Host", role: "", organization: "Private Company")
        viewModel.dismissLowerThird()
        viewModel.clearAllOverlays()

        let kinds = viewModel.supportEvents.map(\.kind)
        XCTAssertTrue(kinds.contains(.countdownStarted))
        XCTAssertTrue(kinds.contains(.countdownStopped))
        XCTAssertTrue(kinds.contains(.tickerStarted))
        XCTAssertTrue(kinds.contains(.tickerStopped))
        XCTAssertTrue(kinds.contains(.lowerThirdShown))
        XCTAssertTrue(kinds.contains(.lowerThirdHidden))
        XCTAssertTrue(kinds.contains(.overlaysCleared))
        XCTAssertFalse(viewModel.supportEvents.contains { $0.detail.localizedStandardContains("Private countdown title") })
        XCTAssertFalse(viewModel.supportEvents.contains { $0.detail.localizedStandardContains("Customer ticker text") })
        XCTAssertFalse(viewModel.supportEvents.contains { $0.detail.localizedStandardContains("Private Host") })
        XCTAssertFalse(viewModel.supportEvents.contains { $0.detail.localizedStandardContains("Private Company") })
    }

    func testPageInterceptAutoReenabledEventAppearsInSanitizedSupportReport() {
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 0),
            kind: .pageInterceptAutoReenabled,
            detail: "reason=timeout"
        )

        let report = LiveSupportReport.makePlainText(
            snapshot: diagnosticsSnapshot(),
            checks: [],
            events: [event],
            generatedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertTrue(report.contains("page.intercept.auto-reenabled"))
        XCTAssertTrue(report.contains("reason=timeout"))
    }

    func testPageInterceptAndPlaybackRuntimeEventsAppearInSupportReport() {
        let events: [LiveSupportEvent] = [
            LiveSupportEvent(timestamp: Date(timeIntervalSince1970: 0), kind: .pageInterceptEnabled, detail: "state=enabled"),
            LiveSupportEvent(timestamp: Date(timeIntervalSince1970: 1), kind: .pageInterceptDisabled, detail: "state=disabled"),
            LiveSupportEvent(timestamp: Date(timeIntervalSince1970: 2), kind: .pageInterceptForwardedToWPS, detail: "direction=next,pid=123"),
            LiveSupportEvent(timestamp: Date(timeIntervalSince1970: 3), kind: .pageInterceptWPSNotRunning, detail: "state=notRunning"),
            LiveSupportEvent(timestamp: Date(timeIntervalSince1970: 4), kind: .systemVolumeSynced, detail: "deviceID=42,volume=0.5"),
            LiveSupportEvent(timestamp: Date(timeIntervalSince1970: 5), kind: .playbackReachedEnd, detail: "state=ended")
        ]

        let report = LiveSupportReport.makePlainText(
            snapshot: diagnosticsSnapshot(),
            checks: [],
            events: events,
            generatedAt: Date(timeIntervalSince1970: 6)
        )

        XCTAssertTrue(report.contains("page.intercept.enabled"))
        XCTAssertTrue(report.contains("page.intercept.disabled"))
        XCTAssertTrue(report.contains("page.intercept.forwarded-to-wps"))
        XCTAssertTrue(report.contains("page.intercept.wps-not-running"))
        XCTAssertTrue(report.contains("system.volume.synced"))
        XCTAssertTrue(report.contains("playback.reached-end"))
    }

    func testRuntimeSourcesDoNotUseReleasePrintDiagnostics() throws {
        let disallowedSources = [
            try sourceText("ViewModel.swift"),
            try sourceText("Engines/AVPlayerCoordinator.swift")
        ]

        for source in disallowedSources {
            XCTAssertFalse(source.contains("print("))
        }
    }

    private func makeViewModel() -> SwitcherViewModel {
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: .standard
        )
        viewModel.liveAudioFadeDuration = 0
        viewModel.externalScreenProvider = { NSScreen.main ?? NSScreen.screens.first }
        viewModel.programActivationSideEffects.presentKeynote = { _ in }
        viewModel.programActivationSideEffects.openPPTX = { _ in }
        viewModel.programActivationSideEffects.presentActiveDeck = {}
        viewModel.programActivationSideEffects.presentInvalidDeckAlert = { _ in }
        viewModel.programActivationSideEffects.stopDeck = {}
        return viewModel
    }

    private func diagnosticsSnapshot() -> LiveDiagnosticsSnapshot {
        LiveDiagnosticsSnapshot(
            appVersion: "0.4.0",
            operatingSystem: "macOS Test",
            architecture: "arm64-test",
            preflight: LivePreflightSnapshot(
                appVersion: "0.4.0",
                hasExternalDisplay: true,
                isBroadcasting: false,
                broadcastSafetyNotice: nil,
                programItemCount: 0,
                currentProgramTitle: nil,
                currentProgramSource: nil,
                bgmItemCount: 0,
                isBGMPlaying: false,
                isBGMAudioTakeoverActive: false,
                isSpeakerMode: false,
                isPanicMode: false,
                isPageInterceptEnabled: false,
                activeOverlayCount: 0,
                wallpaperCount: 0,
                autoPlayNextVideoOnEnd: false,
                effectiveMediaVolume: 0.8,
                effectiveBGMVolume: 0.5
            )
        )
    }

    private func sourceText(_ relativePath: String) throws -> String {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try String(contentsOf: candidate, encoding: .utf8)
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
