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

        func show(on screen: NSScreen?, fullScreen: Bool) {
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
        viewModel.currentBGMItem = item
        viewModel.isBGMPlaying = true
        viewModel.isBGMAudioTakeoverActive = true
        viewModel.bgmProgress = 0.6
        viewModel.bgmCurrentTime = 42
        viewModel.bgmDuration = 100

        viewModel.bgmDidFail()

        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertFalse(viewModel.isBGMAudioTakeoverActive)
        XCTAssertEqual(viewModel.bgmProgress, 0)
        XCTAssertEqual(viewModel.bgmCurrentTime, 0)
        XCTAssertNil(viewModel.bgmDuration)
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
        viewModel.isBroadcasting = true
        viewModel.handleExternalDisplayLost()

        let kinds = viewModel.supportEvents.map(\.kind)
        XCTAssertTrue(kinds.contains(.projectionStartFailed))
        XCTAssertTrue(kinds.contains(.projectionStarted))
        XCTAssertTrue(kinds.contains(.projectionStopped))
        XCTAssertTrue(kinds.contains(.projectionLost))
        XCTAssertFalse(viewModel.supportEvents.contains { $0.detail.localizedStandardContains("/Users/") })
    }

    func testOverlaySupportEventsDoNotRecordOperatorText() {
        let viewModel = makeViewModel()

        viewModel.startCountdown(seconds: 10, title: "Private countdown title")
        viewModel.stopCountdown()
        viewModel.startTicker(text: "Customer ticker text")
        viewModel.stopTicker()
        viewModel.showLowerThird(name: "Private Host", title: "Private Company")
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

    private func makeViewModel() -> SwitcherViewModel {
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: .standard
        )
        viewModel.liveAudioFadeDuration = 0
        viewModel.externalScreenProvider = { NSScreen.main ?? NSScreen.screens.first }
        viewModel.keynotePresentationHandler = { _ in }
        viewModel.pptxOpenHandler = { _ in }
        viewModel.activeDeckPresentationHandler = {}
        viewModel.invalidDeckHandler = { _ in }
        viewModel.deckStopHandler = {}
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
}
