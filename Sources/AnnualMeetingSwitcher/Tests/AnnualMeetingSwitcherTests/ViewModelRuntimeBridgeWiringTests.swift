import AppKit
import SwiftUI
import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelRuntimeBridgeWiringTests: XCTestCase {
    func testMediaPortLoadStillLoadsAVCoordinatorAndSetsCallbackGeneration() {
        let viewModel = makeViewModel()
        let item = mediaProgram()
        viewModel.programItems = [item]

        viewModel.dispatchRuntimeFacadeAction(.operatorSelectedProgram(item.id))

        XCTAssertEqual(viewModel.avCoordinator.currentURL, item.sourceURL)
        XCTAssertEqual(viewModel.activeRuntimeMediaCallbackGenerationForTesting, viewModel.runtime.state.media.generation)
        XCTAssertEqual(viewModel.activeRuntimeMediaCallbackURLForTesting, item.sourceURL)
    }

    func testMediaPortStopStillClearsActiveMediaCallbackGeneration() {
        let viewModel = makeViewModel()
        let ports = SwitcherRuntimePortBundle()
        let url = URL(fileURLWithPath: "/tmp/live-switcher-video.mp4")
        viewModel.configureRuntimePortHandlers(ports)
        ports.mediaPlaybackPort.load(url: url, generation: 7)

        ports.mediaPlaybackPort.stop(generation: 7)

        XCTAssertNil(viewModel.activeRuntimeMediaCallbackGenerationForTesting)
        XCTAssertNil(viewModel.activeRuntimeMediaCallbackURLForTesting)
    }

    func testBGMPortPrepareStillPreparesRuntimeBGM() {
        let viewModel = makeViewModel()
        let item = bgmItem()
        viewModel.bgmItems = [item]

        viewModel.dispatchRuntimeFacadeAction(.operatorSelectedBGM(item.id))

        XCTAssertEqual(viewModel.currentBGMItem, item)
        XCTAssertEqual(viewModel.activeRuntimeBGMCallbackGenerationForTesting, viewModel.runtime.state.bgm.generation)
        XCTAssertEqual(viewModel.activeRuntimeBGMCallbackItemIDForTesting, item.id)
        XCTAssertEqual(viewModel.activeRuntimeBGMCallbackURLForTesting, item.url)
    }

    func testBGMPortPlayStillStartsBGMAndFadesIn() {
        let viewModel = makeViewModel()
        let item = bgmItem()
        viewModel.bgmItems = [item]

        viewModel.dispatchRuntimeFacadeAction(.operatorSelectedBGM(item.id))

        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertNotNil(viewModel.bgmProgressTimerForTesting)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.bgmFadeDuration, viewModel.liveAudioFadeDuration)
    }

    func testBGMPortStopStillStopsBGMWithFade() {
        let viewModel = makeViewModel()
        let item = bgmItem()
        viewModel.bgmItems = [item]
        viewModel.dispatchRuntimeFacadeAction(.operatorSelectedBGM(item.id))

        viewModel.dispatchRuntimeFacadeAction(.operatorStoppedBGM)

        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertNil(viewModel.activeRuntimeBGMCallbackGenerationForTesting)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.bgmFadeDuration, viewModel.liveAudioFadeDuration)
    }

    func testBGMTimerPortStillStartsAndStopsGenerationBoundTimer() {
        let viewModel = makeViewModel()
        let ports = SwitcherRuntimePortBundle()
        viewModel.configureRuntimePortHandlers(ports)

        ports.bgmTimerPort.start(generation: 4)
        XCTAssertEqual(viewModel.activeBGMTimerGenerationForTesting, 4)

        ports.bgmTimerPort.stop(generation: 4)
        XCTAssertNil(viewModel.activeBGMTimerGenerationForTesting)
    }

    func testProjectionPortStartStillCallsRuntimeProjectionOutputPath() throws {
        let viewModel = try makeViewModelWithDisplay()
        let output = OutputWindowControllerSpy()
        viewModel.outputWindowControllerFactory = { output }

        viewModel.dispatchRuntimeFacadeAction(.operatorToggledProjection)

        XCTAssertEqual(output.showCount, 1)
        XCTAssertTrue(viewModel.isBroadcasting)
    }

    func testProjectionPortStopStillCallsRuntimeProjectionOutputPath() throws {
        let viewModel = try makeViewModelWithDisplay()
        let output = OutputWindowControllerSpy()
        viewModel.outputWindowControllerFactory = { output }
        viewModel.dispatchRuntimeFacadeAction(.operatorToggledProjection)

        viewModel.dispatchRuntimeFacadeAction(.operatorToggledProjection)

        XCTAssertEqual(output.hideCount, 1)
        XCTAssertFalse(viewModel.isBroadcasting)
    }

    func testPPTPortStartStillStartsEventTapFromRuntime() {
        let viewModel = makeViewModel()
        viewModel.pageInterceptSideEffectsEnabled = false

        viewModel.dispatchRuntimeFacadeAction(.operatorSetPPTMode(true, source: .programmatic))

        XCTAssertTrue(viewModel.isPageInterceptEnabled)
        XCTAssertTrue(viewModel.runtime.state.ppt.isEventTapActive)
    }

    func testPPTPortStopStillStopsEventTapFromRuntime() {
        let viewModel = makeViewModel()
        viewModel.pageInterceptSideEffectsEnabled = false
        viewModel.dispatchRuntimeFacadeAction(.operatorSetPPTMode(true, source: .programmatic))

        viewModel.dispatchRuntimeFacadeAction(.operatorSetPPTMode(false, source: .programmatic))

        XCTAssertFalse(viewModel.isPageInterceptEnabled)
        XCTAssertFalse(viewModel.runtime.state.ppt.isEventTapActive)
    }

    func testAutomationNoticePortShowStillUpdatesFacadeNoticeAndCancelsPreviousExpiry() {
        let viewModel = makeViewModel()
        let oldTask = Task<Void, Never> { try? await Task.sleep(nanoseconds: 10_000_000_000) }
        viewModel.cleanupBag.automationNoticeExpiryTask = oldTask

        viewModel.dispatchRuntimeFacadeAction(.automationNoticeRequested(action: "keynote.next-slide"))

        XCTAssertTrue(oldTask.isCancelled)
        XCTAssertEqual(viewModel.automationRuntimeNotice?.action, "keynote.next-slide")
        XCTAssertTrue(viewModel.automationNoticeExpiryTaskIsActiveForTesting)
    }

    func testAutomationNoticePortExpireStillSchedulesExpiryTask() {
        let viewModel = makeViewModel()

        viewModel.dispatchRuntimeFacadeAction(.automationNoticeRequested(action: "keynote.next-slide"))

        XCTAssertTrue(viewModel.automationNoticeExpiryTaskIsActiveForTesting)
        XCTAssertEqual(viewModel.cleanupBag.automationNoticeExpiryTaskNoticeID, viewModel.automationRuntimeNotice?.id)
    }

    func testSupportPortRecordStillSyncsSupportFacade() {
        let viewModel = makeViewModel()
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .projectionStarted,
            detail: "source=wiring-test"
        )

        viewModel.dispatchRuntimeFacadeAction(.supportEventRecorded(event))

        XCTAssertEqual(viewModel.supportEvents, [event])
        XCTAssertEqual(viewModel.runtime.state.support.events, [event])
    }

    func testAutomationPortRunStillExecutesRunnerAndRoutesFailureToSupportAndNotice() async {
        let viewModel = makeViewModel()
        let finished = expectation(description: "automation command finished")
        viewModel.automationCommandDidFinishForTesting = { finished.fulfill() }
        viewModel.automationCommandRunnerForTesting = { _, _ in
            throw AppleScriptError.executionFailed(action: "keynote.next-slide", message: "failed")
        }

        viewModel.dispatchRuntimeFacadeAction(
            .automationScriptRequested(script: "tell application \"Keynote\"", action: "keynote.next-slide")
        )
        await fulfillment(of: [finished], timeout: 1)

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .appleScriptFailed })
        XCTAssertEqual(viewModel.automationRuntimeNotice?.action, "keynote.next-slide")
    }

    func testPersistencePortSpecificHandlersStillWriteUserDefaultsKeys() throws {
        let suiteName = "ViewModelRuntimeBridgeWiringTests.persistence.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let viewModel = makeViewModel(userDefaults: defaults)

        viewModel.consoleMode = .live
        viewModel.themeOverride = .system
        viewModel.audioStrategy = .bgmOnly
        viewModel.isSpeakerMode = true
        viewModel.dispatchRuntimeFacadeAction(.operatorSelectedBGMPlayMode(.sequential))

        XCTAssertEqual(defaults.string(forKey: "consoleMode"), ConsoleMode.live.rawValue)
        XCTAssertEqual(defaults.string(forKey: "themeOverride"), ThemeOverride.system.rawValue)
        XCTAssertEqual(defaults.string(forKey: "audioStrategy"), AudioStrategy.bgmOnly.rawValue)
        XCTAssertTrue(defaults.bool(forKey: "speakerMode"))
        XCTAssertEqual(defaults.string(forKey: "bgmPlayMode"), BGMPlayMode.sequential.rawValue)
    }

    func testAudioRoutingPortStillAppliesRuntimeAudioRouting() {
        let viewModel = makeViewModel()

        viewModel.mediaVolume = 0.25

        XCTAssertNotNil(viewModel.lastAudioRoutingTransition)
        XCTAssertEqual(viewModel.avCoordinator.volume, viewModel.runtime.state.audio.effectiveMedia, accuracy: 0.0001)
    }

    func testImageAssetPortStillLoadsBackgroundAndCornerLogo() throws {
        let viewModel = makeViewModel()
        let background = try makePNG(name: "background")
        let logo = try makePNG(name: "logo")

        viewModel.activeWallpaperURL = background
        viewModel.cornerLogoURL = logo

        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertNotNil(viewModel.cornerLogoImage)
    }

    private func makeViewModel(userDefaults: UserDefaults? = nil) -> SwitcherViewModel {
        let defaults = userDefaults ?? {
            let suiteName = "ViewModelRuntimeBridgeWiringTests.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            return defaults
        }()
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
    }

    private func makeViewModelWithDisplay() throws -> SwitcherViewModel {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }
        let viewModel = makeViewModel()
        viewModel.externalScreenProvider = { screen }
        return viewModel
    }

    private func mediaProgram() -> ProgramItem {
        ProgramItem(
            title: "Video",
            subtitle: "VIDEO",
            sourceURL: URL(fileURLWithPath: "/tmp/live-switcher-video.mp4")
        )
    }

    private func bgmItem() -> BGMItem {
        BGMItem(
            title: "Walk-in",
            url: URL(fileURLWithPath: "/tmp/live-switcher-bgm.mp3")
        )
    }

    private func makePNG(name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("live-switcher-\(name)-\(UUID().uuidString)")
            .appendingPathExtension("png")
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 2, height: 2).fill()
        image.unlockFocus()
        let data = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url)
        return url
    }
}

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
