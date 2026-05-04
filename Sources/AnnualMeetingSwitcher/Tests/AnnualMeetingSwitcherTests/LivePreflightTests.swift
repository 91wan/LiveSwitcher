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
        XCTAssertTrue(display.message.localizedStandardContains("Needs hardware"))
        XCTAssertTrue(display.message.localizedStandardContains("Do not project"))
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
        XCTAssertTrue(panic.message.localizedStandardContains("Panic blackout is active"))
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
        XCTAssertTrue(takeover.message.localizedStandardContains("Media audio is muted by BGM takeover"))
    }

    func testNoBGMItemsWarnsAudioReadiness() {
        let viewModel = makeViewModel()
        viewModel.bgmItems = []

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let bgm = check("audio.bgm-library", in: checks)

        XCTAssertEqual(bgm.group, .audio)
        XCTAssertEqual(bgm.status, .warn)
        XCTAssertTrue(bgm.message.localizedStandardContains("No BGM tracks loaded"))
    }

    func testNoWallpaperWarnsPlaybackFallbackReadiness() {
        let viewModel = makeViewModel()
        viewModel.backgroundWallpapers = []

        let checks = LivePreflightCheck.build(from: viewModel.livePreflightSnapshot)
        let wallpaper = check("playback.wallpaper", in: checks)

        XCTAssertEqual(wallpaper.group, .playback)
        XCTAssertEqual(wallpaper.status, .warn)
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
        XCTAssertTrue(overlays.message.localizedStandardContains("3 overlays active"))
    }

    func testPlainTextReportContainsVersionAndNoPrivatePaths() {
        let viewModel = makeViewModel()
        viewModel.externalScreenProvider = { nil }
        viewModel.startTicker(text: "Welcome")

        let report = viewModel.livePreflightReportText()

        XCTAssertTrue(report.contains("LiveSwitcher Preflight v0.2.2"))
        XCTAssertTrue(report.contains("Display"))
        XCTAssertFalse(report.localizedStandardContains("/Users/" + "liuchangxi"))
        XCTAssertFalse(report.localizedStandardContains("Ditu" + "LiveSwitcher"))
        XCTAssertFalse(report.localizedStandardContains("com." + "didu"))
    }
}
