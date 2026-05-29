import AppKit
import SwiftUI
import XCTest
@testable import LiveSwitcher

@MainActor
final class SwitcherViewModelSmokeTests: XCTestCase {
    private final class OutputWindowControllerSpy: OutputWindowControlling {
        var onExternalDisplayUnavailable: (() -> Void)?
        private(set) var mountCount = 0
        private(set) var showCount = 0
        private(set) var hideCount = 0
        private(set) var lastShowScreenWasNil = false

        func mountAnyView(rootView: AnyView) {
            mountCount += 1
        }

        func show(on screen: NSScreen?) {
            showCount += 1
            lastShowScreenWasNil = (screen == nil)
        }

        func hide() {
            hideCount += 1
        }
    }

    private func makeViewModel(userDefaults: UserDefaults? = nil, loadPersistedData: Bool = false) -> SwitcherViewModel {
        let viewModel = SwitcherViewModel(
            loadPersistedData: loadPersistedData,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults ?? .standard
        )
        viewModel.externalScreenProvider = { NSScreen.main ?? NSScreen.screens.first }
        viewModel.keynotePresentationHandler = { _ in }
        viewModel.pptxOpenHandler = { _ in }
        viewModel.activeDeckPresentationHandler = {}
        viewModel.invalidDeckHandler = { _ in }
        viewModel.deckStopHandler = {}
        return viewModel
    }

    private func makeIsolatedDefaults() -> (suiteName: String, defaults: UserDefaults) {
        let suiteName = "LiveSwitcherTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (suiteName, defaults)
    }

    private func makeTempFileURL(ext: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        FileManager.default.createFile(atPath: url.path, contents: Data("stub".utf8))
        return url
    }

    private func makeEmptyTempFileURL(ext: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        FileManager.default.createFile(atPath: url.path, contents: Data())
        return url
    }

    private func makeTempDirectoryURL(ext: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    private func makeWallpaperURL() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")

        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 8, height: 8)).fill()
        image.unlockFocus()

        let tiffData = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiffData))
        let pngData = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try pngData.write(to: url)
        return url
    }

    func testLoopModeCyclesThroughExpectedSequence() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.bgmPlayMode, .loopAll)

        viewModel.toggleLoopMode()
        XCTAssertEqual(viewModel.bgmPlayMode, .loopOne)

        viewModel.toggleLoopMode()
        XCTAssertEqual(viewModel.bgmPlayMode, .sequential)

        viewModel.toggleLoopMode()
        XCTAssertEqual(viewModel.bgmPlayMode, .loopAll)
    }

    func testBGMVolumeAdjustmentsClampBetweenZeroAndOne() {
        let viewModel = makeViewModel()

        viewModel.bgmVolume = 0.02
        viewModel.bgmVolumeDown()
        XCTAssertEqual(viewModel.bgmVolume, 0.0, accuracy: 0.0001)

        viewModel.bgmVolume = 0.98
        viewModel.bgmVolumeUp()
        XCTAssertEqual(viewModel.bgmVolume, 1.0, accuracy: 0.0001)
    }

    func testMoveBGMItemsWithinCategoryDoesNotReorderOtherCategories() {
        let viewModel = makeViewModel()
        let warmA = BGMItem(title: "Warm A", url: URL(fileURLWithPath: "/tmp/warm-a.mp3"), category: .warmUp)
        let ambient = BGMItem(title: "Ambient", url: URL(fileURLWithPath: "/tmp/ambient.mp3"), category: .ambient)
        let warmB = BGMItem(title: "Warm B", url: URL(fileURLWithPath: "/tmp/warm-b.mp3"), category: .warmUp)
        let exit = BGMItem(title: "Exit", url: URL(fileURLWithPath: "/tmp/exit.mp3"), category: .exit)
        let warmC = BGMItem(title: "Warm C", url: URL(fileURLWithPath: "/tmp/warm-c.mp3"), category: .warmUp)
        viewModel.bgmItems = [warmA, ambient, warmB, exit, warmC]

        viewModel.moveBGMItems(in: .warmUp, from: IndexSet(integer: 2), to: 0)

        XCTAssertEqual(viewModel.bgmItems, [warmC, ambient, warmA, exit, warmB])
    }

    func testTickerAndLowerThirdStateTransitions() {
        let viewModel = makeViewModel()

        viewModel.startTicker(text: "欢迎光临")
        XCTAssertTrue(viewModel.isTickerActive)
        XCTAssertEqual(viewModel.tickerText, "欢迎光临")

        viewModel.stopTicker()
        XCTAssertFalse(viewModel.isTickerActive)

        viewModel.showLowerThird(name: "主持人", title: "开场")
        XCTAssertTrue(viewModel.isLowerThirdVisible)
        XCTAssertEqual(viewModel.lowerThirdName, "主持人")
        XCTAssertEqual(viewModel.lowerThirdTitle, "开场")

        viewModel.dismissLowerThird()
        XCTAssertFalse(viewModel.isLowerThirdVisible)
    }

    func testCountdownStartAndStopResetState() {
        let viewModel = makeViewModel()

        viewModel.startCountdown(seconds: 10, title: "即将开始")
        XCTAssertTrue(viewModel.isCountdownActive)
        XCTAssertEqual(viewModel.countdownTitle, "即将开始")
        XCTAssertEqual(viewModel.countdownSeconds, 10)

        viewModel.stopCountdown()
        XCTAssertFalse(viewModel.isCountdownActive)
        XCTAssertEqual(viewModel.countdownSeconds, 0)
    }

    func testCountdownTickAutoStopsAtZero() {
        let viewModel = makeViewModel()

        viewModel.startCountdown(seconds: 2, title: "开场倒计时")

        viewModel.countdownTick()
        XCTAssertTrue(viewModel.isCountdownActive)
        XCTAssertEqual(viewModel.countdownSeconds, 1)

        viewModel.countdownTick()
        XCTAssertFalse(viewModel.isCountdownActive)
        XCTAssertEqual(viewModel.countdownSeconds, 0)
    }

    func testRestartingCountdownReplacesRemainingSeconds() {
        let viewModel = makeViewModel()

        viewModel.startCountdown(seconds: 30, title: "First")
        viewModel.countdownTick()
        XCTAssertEqual(viewModel.countdownSeconds, 29)

        viewModel.startCountdown(seconds: 5, title: "Second")

        XCTAssertTrue(viewModel.isCountdownActive)
        XCTAssertEqual(viewModel.countdownTitle, "Second")
        XCTAssertEqual(viewModel.countdownSeconds, 5)
    }

    func testOverlayStartMethodsRejectUnsafeInput() {
        let viewModel = makeViewModel()

        viewModel.startTicker(text: "   ")
        XCTAssertFalse(viewModel.isTickerActive)

        viewModel.showLowerThird(name: "   ", title: "主持")
        XCTAssertFalse(viewModel.isLowerThirdVisible)

        viewModel.startCountdown(seconds: 0, title: "即将开始")
        XCTAssertFalse(viewModel.isCountdownActive)
        XCTAssertEqual(viewModel.countdownSeconds, 0)

        viewModel.startCountdown(seconds: -5, title: "即将开始")
        XCTAssertFalse(viewModel.isCountdownActive)
        XCTAssertEqual(viewModel.countdownSeconds, 0)
    }

    func testClearAllOverlaysResetsCountdownTickerAndLowerThird() {
        let viewModel = makeViewModel()

        viewModel.startCountdown(seconds: 30, title: "准备开始")
        viewModel.startTicker(text: "欢迎光临")
        viewModel.showLowerThird(name: "主持人", title: "开场")

        XCTAssertTrue(viewModel.isCountdownActive)
        XCTAssertTrue(viewModel.isTickerActive)
        XCTAssertTrue(viewModel.isLowerThirdVisible)

        viewModel.clearAllOverlays()

        XCTAssertFalse(viewModel.isCountdownActive)
        XCTAssertEqual(viewModel.countdownSeconds, 0)
        XCTAssertFalse(viewModel.isTickerActive)
        XCTAssertFalse(viewModel.isLowerThirdVisible)
        XCTAssertEqual(viewModel.lowerThirdName, "")
        XCTAssertEqual(viewModel.lowerThirdTitle, "")
    }

    func testMixedStrategyKeepsMediaAndBGMChannelsActive() {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0

        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.25
        viewModel.audioStrategy = .mixed
        viewModel.isBGMPlaying = true
        viewModel.currentProgramItem = ProgramItem(
            title: "片头",
            subtitle: "MP4",
            sourceURL: URL(fileURLWithPath: "/tmp/opening.mp4")
        )
        viewModel.avCoordinator.isPlaying = true

        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.2, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0.2, accuracy: 0.0001)
    }

    func testFollowProgramFallsBackToBGMWhenMediaIsNotPlaying() {
        let viewModel = makeViewModel()

        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.25
        viewModel.audioStrategy = .followProgram
        viewModel.currentProgramItem = ProgramItem(
            title: "片头",
            subtitle: "MP4",
            sourceURL: URL(fileURLWithPath: "/tmp/opening.mp4")
        )

        viewModel.avCoordinator.isPlaying = false
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.2, accuracy: 0.0001)

        viewModel.avCoordinator.isPlaying = true
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0, accuracy: 0.0001)
    }

    func testFollowSourceAndSpeakerModeDoNotResurrectMutedBGM() {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0

        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.9
        viewModel.audioStrategy = .followSource
        viewModel.currentProgramItem = ProgramItem(
            title: "网页",
            subtitle: "HTML",
            sourceURL: URL(fileURLWithPath: "/tmp/lobby.html")
        )
        viewModel.toggleSpeakerMode()

        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0, accuracy: 0.0001)
    }

    func testSpeakerModeCompressesBGMWithoutChangingAudioStrategy() {
        let viewModel = makeViewModel()
        viewModel.masterVolume = 0.8
        viewModel.bgmVolume = 0.5
        viewModel.audioStrategy = .mixed

        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.4, accuracy: 0.0001)

        viewModel.toggleSpeakerMode()

        XCTAssertTrue(viewModel.isSpeakerMode)
        XCTAssertEqual(viewModel.audioStrategy, .mixed)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.056, accuracy: 0.0001)
    }

    func testSpeakerModeDucksMediaAudioWithoutLiftingLowerUserFader() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.audioStrategy = .mixed
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.switchToProgram(ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL))
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)

        viewModel.toggleSpeakerMode()

        XCTAssertTrue(viewModel.isSpeakerMode)
        XCTAssertEqual(viewModel.audioStrategy, .mixed)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.056, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0.056, accuracy: 0.0001)

        viewModel.mediaVolume = 0.02
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.016, accuracy: 0.0001)
    }

    func testLiveSpeakerModeToggleDucksMediaAndBGMThroughRouting() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.5
        viewModel.audioStrategy = .mixed
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.isBGMPlaying = true
        viewModel.switchToProgram(ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL))
        viewModel.toggleSpeakerMode()

        XCTAssertTrue(viewModel.isSpeakerMode)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.056, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.056, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0.056, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0.056, accuracy: 0.0001)
    }

    func testBGMPlaybackDoesNotImplicitlyTakeOverMediaAudioWithoutChangingStrategy() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.25
        viewModel.audioStrategy = .mixed

        let videoURL = try makeTempFileURL(ext: "mp4")
        let bgmURL = try makeTempFileURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: bgmURL)
        }

        let videoItem = ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL)
        let bgmItem = BGMItem(title: "暖场音乐", url: bgmURL, category: .warmUp)
        viewModel.switchToProgram(videoItem)
        XCTAssertEqual(viewModel.audioStrategy, .mixed)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)

        viewModel.toggleBGM(bgmItem)

        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertFalse(viewModel.isBGMAudioTakeoverActive)
        XCTAssertEqual(viewModel.audioStrategy, .mixed)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.2, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0.2, accuracy: 0.0001)
    }

    func testStoppingBGMRestoresMediaAudioUsingExistingStrategy() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.25
        viewModel.audioStrategy = .mixed

        let videoURL = try makeTempFileURL(ext: "mp4")
        let bgmURL = try makeTempFileURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: bgmURL)
        }

        let videoItem = ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL)
        let bgmItem = BGMItem(title: "暖场音乐", url: bgmURL, category: .warmUp)
        viewModel.switchToProgram(videoItem)
        viewModel.toggleBGM(bgmItem)

        viewModel.toggleBGM(bgmItem)

        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertFalse(viewModel.isBGMAudioTakeoverActive)
        XCTAssertEqual(viewModel.audioStrategy, .mixed)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0, accuracy: 0.0001)
    }

    func testBGMPlaybackDoesNotOverrideFollowSourceStrategy() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.25
        viewModel.audioStrategy = .followSource

        let videoURL = try makeTempFileURL(ext: "mp4")
        let bgmURL = try makeTempFileURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: bgmURL)
        }

        let videoItem = ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL)
        let bgmItem = BGMItem(title: "暖场音乐", url: bgmURL, category: .warmUp)
        viewModel.switchToProgram(videoItem)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0, accuracy: 0.0001)

        viewModel.toggleBGM(bgmItem)

        XCTAssertFalse(viewModel.isBGMAudioTakeoverActive)
        XCTAssertEqual(viewModel.audioStrategy, .followSource)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0, accuracy: 0.0001)
    }

    func testChangingAudioStrategyWhileBGMIsPlayingUpdatesEffectiveVolumesAndPlayers() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.25
        viewModel.audioStrategy = .mixed

        let videoURL = try makeTempFileURL(ext: "mp4")
        let bgmURL = try makeTempFileURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: bgmURL)
        }

        viewModel.switchToProgram(ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL))
        viewModel.toggleBGM(BGMItem(title: "暖场音乐", url: bgmURL, category: .warmUp))

        XCTAssertEqual(viewModel.avCoordinator.volume, 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0.2, accuracy: 0.0001)

        viewModel.audioStrategy = .followProgram
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0, accuracy: 0.0001)

        viewModel.audioStrategy = .bgmOnly
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.2, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0.2, accuracy: 0.0001)
    }

    func testSwitchingBGMItemsCancelsStaleFadeTargets() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.25
        viewModel.audioStrategy = .mixed

        let videoURL = try makeTempFileURL(ext: "mp4")
        let firstBGMURL = try makeTempFileURL(ext: "mp3")
        let secondBGMURL = try makeTempFileURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: firstBGMURL)
            try? FileManager.default.removeItem(at: secondBGMURL)
        }

        let videoItem = ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL)
        let firstBGM = BGMItem(title: "暖场音乐 A", url: firstBGMURL, category: .warmUp)
        let secondBGM = BGMItem(title: "暖场音乐 B", url: secondBGMURL, category: .warmUp)
        viewModel.switchToProgram(videoItem)

        viewModel.toggleBGM(firstBGM)
        viewModel.toggleBGM(secondBGM)

        XCTAssertEqual(viewModel.currentBGMItem, secondBGM)
        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertFalse(viewModel.isBGMAudioTakeoverActive)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0.2, accuracy: 0.0001)
    }

    func testBGMNextPreviousAreNoopsWhenOnlyOneTrackInCurrentCategory() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let bgmURL = try makeTempFileURL(ext: "mp3")
        defer { try? FileManager.default.removeItem(at: bgmURL) }
        let item = BGMItem(title: "Only Track", url: bgmURL, category: .warmUp)
        viewModel.bgmItems = [item]
        viewModel.currentBGMItem = item
        viewModel.isBGMPlaying = true

        viewModel.playNextBGM()
        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertEqual(viewModel.currentBGMItem?.id, item.id)

        viewModel.playPreviousBGM()
        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertEqual(viewModel.currentBGMItem?.id, item.id)
    }

    func testFallbackBGMSeekUpdatesCurrentTimeAndKeepsDuration() {
        let viewModel = makeViewModel()
        viewModel.bgmDuration = 200

        viewModel.seekBGM(toProgress: 0.25)

        XCTAssertEqual(viewModel.bgmProgress, 0.25, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmCurrentTime, 50, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(viewModel.bgmDuration), 200, accuracy: 0.0001)
    }

    func testFallbackBGMSeekWithoutKnownDurationDoesNotMoveDisplayedProgress() {
        let viewModel = makeViewModel()
        viewModel.bgmDuration = nil
        viewModel.bgmCurrentTime = 18
        viewModel.bgmProgress = 0.4

        viewModel.seekBGM(toProgress: 0.8)

        XCTAssertEqual(viewModel.bgmProgress, 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmCurrentTime, 18, accuracy: 0.0001)
        XCTAssertNil(viewModel.bgmDuration)
    }

    func testBGMDurationRejectsNonFiniteValues() {
        let viewModel = makeViewModel()

        viewModel.bgmDuration = .infinity

        XCTAssertNil(viewModel.bgmDuration)
    }

    func testFallbackBGMSeekToBeginningKeepsKnownDuration() {
        let viewModel = makeViewModel()
        viewModel.bgmDuration = 90
        viewModel.bgmCurrentTime = 45
        viewModel.bgmProgress = 0.5

        viewModel.seekBGMToBeginning()

        XCTAssertEqual(viewModel.bgmProgress, 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmCurrentTime, 0, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(viewModel.bgmDuration), 90, accuracy: 0.0001)
    }

    func testExplicitBGMTakeoverStillMutesMediaWhenOperatorEnablesIt() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.25
        viewModel.audioStrategy = .mixed
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        viewModel.isBGMPlaying = true
        viewModel.isBGMAudioTakeoverActive = true
        viewModel.applyAudioRouting()

        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.2, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0.2, accuracy: 0.0001)
    }

    func testPanicModeForcesEffectiveMediaAndBGMVolumesToZero() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.25
        viewModel.audioStrategy = .mixed
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.2, accuracy: 0.0001)

        viewModel.togglePanicMode()

        XCTAssertTrue(viewModel.isPanicMode)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0, accuracy: 0.0001)
    }

    func testPanicRestoreResumesOnlyIfMediaWasPlayingBefore() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.togglePanicMode()
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)

        viewModel.togglePanicMode()
        XCTAssertFalse(viewModel.isPanicMode)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
    }

    func testPanicRestoreDoesNotAutoPlayPausedMedia() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        viewModel.avCoordinator.pause()

        viewModel.togglePanicMode()
        viewModel.togglePanicMode()

        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }

    func testPanicRestoreDoesNotResumeIfProgramChangedDuringPanic() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let firstURL = try makeTempFileURL(ext: "mp4")
        let secondURL = try makeTempFileURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: firstURL)
        let second = ProgramItem(title: "Awards", subtitle: "MP4", sourceURL: secondURL)

        viewModel.switchToProgram(first)
        viewModel.togglePanicMode()
        viewModel.switchToProgram(second)
        viewModel.avCoordinator.pause()

        viewModel.togglePanicMode()

        XCTAssertEqual(viewModel.currentProgramItem?.id, second.id)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }

    func testFadeToBlackDoesNotPauseMedia() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        viewModel.toggleFadeToBlack()

        XCTAssertTrue(viewModel.isFadeToBlackActive)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
    }

    func testPanicModeOffRestoresCurrentRoutingInsteadOfOldSnapshot() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.25
        viewModel.audioStrategy = .mixed
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        viewModel.togglePanicMode()

        viewModel.masterVolume = 0.5
        viewModel.mediaVolume = 0.2
        viewModel.bgmVolume = 0.4
        viewModel.audioStrategy = .followSource

        viewModel.togglePanicMode()

        XCTAssertFalse(viewModel.isPanicMode)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.1, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0.1, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0, accuracy: 0.0001)
    }

    func testBGMTakeoverPlusPanicNeverResurrectsMediaAudio() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.masterVolume = 0.8
        viewModel.mediaVolume = 0.5
        viewModel.bgmVolume = 0.25
        viewModel.audioStrategy = .mixed
        let videoURL = try makeTempFileURL(ext: "mp4")
        let bgmURL = try makeTempFileURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: bgmURL)
        }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        viewModel.toggleBGM(BGMItem(title: "Walk-in", url: bgmURL, category: .warmUp))
        viewModel.togglePanicMode()

        XCTAssertFalse(viewModel.isBGMAudioTakeoverActive)
        XCTAssertTrue(viewModel.isPanicMode)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0, accuracy: 0.0001)

        viewModel.togglePanicMode()

        XCTAssertFalse(viewModel.isPanicMode)
        XCTAssertFalse(viewModel.isBGMAudioTakeoverActive)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0.2, accuracy: 0.0001)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0.4, accuracy: 0.0001)
    }

    func testAudioStrategyPersistsAcrossViewModelInstances() {
        let (suiteName, defaults) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let writer = makeViewModel(userDefaults: defaults)
        writer.audioStrategy = .followSource

        let reader = makeViewModel(userDefaults: defaults, loadPersistedData: true)
        XCTAssertEqual(reader.audioStrategy, .followSource)
    }

    func testSpeakerModePersistsAcrossViewModelInstances() {
        let (suiteName, defaults) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let writer = makeViewModel(userDefaults: defaults)
        writer.toggleSpeakerMode()

        let reader = makeViewModel(userDefaults: defaults, loadPersistedData: true)
        XCTAssertTrue(reader.isSpeakerMode)
    }

    func testAutoPlayNextVideoPreferencePersistsAcrossViewModelInstances() {
        let (suiteName, defaults) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let defaultReader = makeViewModel(userDefaults: defaults, loadPersistedData: true)
        XCTAssertFalse(defaultReader.autoPlayNextVideoOnEnd)

        let writer = makeViewModel(userDefaults: defaults)
        writer.autoPlayNextVideoOnEnd = true

        let reader = makeViewModel(userDefaults: defaults, loadPersistedData: true)
        XCTAssertTrue(reader.autoPlayNextVideoOnEnd)
    }

    func testProgramPersistenceKeepsFileItemMetadataAlignedWhenActiveDeckItemsAreSkipped() throws {
        let (suiteName, defaults) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let videoURL = try makeTempFileURL(ext: "mp4")
        let htmlURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: htmlURL)
        }

        let writer = makeViewModel(userDefaults: defaults)
        writer.addProgramItem(ProgramItem(title: "Opening Video", subtitle: "VIDEO", sourceURL: videoURL))
        writer.addProgramItem(ProgramItem(title: "Front Keynote", subtitle: "KEY (活动)", sourceURL: nil))
        writer.addProgramItem(ProgramItem(title: "Agenda HTML", subtitle: "HTML", sourceURL: htmlURL))

        let reader = makeViewModel(userDefaults: defaults, loadPersistedData: true)

        XCTAssertEqual(reader.programItems.count, 2)
        XCTAssertEqual(reader.programItems[0].title, "Opening Video")
        XCTAssertEqual(reader.programItems[0].subtitle, "VIDEO")
        XCTAssertEqual(reader.programItems[0].sourceURL, videoURL)
        XCTAssertEqual(reader.programItems[1].title, "Agenda HTML")
        XCTAssertEqual(reader.programItems[1].subtitle, "HTML")
        XCTAssertEqual(reader.programItems[1].sourceURL, htmlURL)
    }

    func testActiveWallpaperSelectionPersistsAcrossViewModelInstances() throws {
        let (suiteName, defaults) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstURL = try makeWallpaperURL()
        let secondURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }

        let writer = makeViewModel(userDefaults: defaults)
        writer.addWallpaper(url: firstURL)
        writer.addWallpaper(url: secondURL)
        writer.setActiveWallpaper(url: secondURL)

        let reader = makeViewModel(userDefaults: defaults, loadPersistedData: true)

        XCTAssertEqual(reader.backgroundWallpapers, [firstURL, secondURL])
        XCTAssertEqual(reader.activeWallpaperURL, secondURL)
        XCTAssertNotNil(reader.backgroundImage)
    }

    func testWallpaperImportRejectsNonImageFiles() throws {
        let viewModel = makeViewModel()
        let wallpaperURL = try makeWallpaperURL()
        let textURL = try makeTempFileURL(ext: "txt")
        defer {
            try? FileManager.default.removeItem(at: wallpaperURL)
            try? FileManager.default.removeItem(at: textURL)
        }

        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.addWallpaper(url: textURL)

        XCTAssertEqual(viewModel.backgroundWallpapers, [wallpaperURL])
        XCTAssertNil(viewModel.activeWallpaperURL)
    }

    func testWallpaperDropSupportDecodesPlainStringPathAsFileURL() {
        let path = "/tmp/my image.png"

        let decodedURL = WallpaperDropSupport.decodeFileURL(from: path)

        XCTAssertEqual(decodedURL, URL(fileURLWithPath: path))
        XCTAssertTrue(decodedURL?.isFileURL == true)
    }

    func testBroadcastToggleShowsAndHidesOutputWindowThroughController() {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()

        viewModel.outputWindowControllerFactory = { outputSpy }

        viewModel.handleBroadcastToggle()
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertFalse(outputSpy.lastShowScreenWasNil)

        viewModel.handleBroadcastToggle()
        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.hideCount, 1)
        XCTAssertEqual(outputSpy.mountCount, 1)
    }

    func testExternalDisplayLossStopsBroadcastAndKeepsCurrentProgram() throws {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.outputWindowControllerFactory = { outputSpy }
        let videoItem = ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL)
        viewModel.switchToProgram(videoItem)
        viewModel.handleBroadcastToggle()

        viewModel.handleExternalDisplayLost()

        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(outputSpy.hideCount, 1)
        XCTAssertEqual(viewModel.broadcastSafetyNotice, "副屏已断开，投射已停止")
    }

    func testBroadcastToggleWithoutExternalDisplayFailsClosedBeforeCreatingOutputWindow() {
        let viewModel = makeViewModel()
        var factoryInvocationCount = 0
        viewModel.externalScreenProvider = { nil }
        viewModel.outputWindowControllerFactory = {
            factoryInvocationCount += 1
            return OutputWindowControllerSpy()
        }

        viewModel.handleBroadcastToggle()

        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertEqual(factoryInvocationCount, 0)
        XCTAssertEqual(viewModel.broadcastSafetyNotice, "未检测到外接屏幕，未开始投射")
    }

    func testSafeBroadcastToggleCanStopProjectionAfterExternalDisplayLoss() {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        viewModel.outputWindowControllerFactory = { outputSpy }

        viewModel.handleBroadcastToggle()
        XCTAssertTrue(viewModel.isBroadcasting)

        viewModel.externalScreenProvider = { nil }
        viewModel.handleSafeBroadcastToggle()

        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.hideCount, 1)
        XCTAssertNil(viewModel.broadcastSafetyNotice)
    }

    func testSafeBroadcastToggleDoesNotRecordStartedWhenDisplayDisappearsBeforeShow() {
        let viewModel = makeViewModel()
        var providerCalls = 0
        viewModel.externalScreenProvider = {
            providerCalls += 1
            return providerCalls == 1 ? (NSScreen.main ?? NSScreen.screens.first) : nil
        }

        viewModel.handleSafeBroadcastToggle()

        let kinds = viewModel.supportEvents.map(\.kind)
        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertTrue(kinds.contains(.projectionLost))
        XCTAssertFalse(kinds.contains(.projectionStarted))
    }

    func testBroadcastToggleDoesNotRecordStartedWhenDisplayDisappearsBeforeShow() {
        let viewModel = makeViewModel()
        var providerCalls = 0
        viewModel.externalScreenProvider = {
            providerCalls += 1
            return providerCalls == 1 ? (NSScreen.main ?? NSScreen.screens.first) : nil
        }

        viewModel.handleBroadcastToggle()

        let kinds = viewModel.supportEvents.map(\.kind)
        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertTrue(kinds.contains(.projectionLost))
        XCTAssertFalse(kinds.contains(.projectionStarted))
    }

    func testBroadcastToggleCycleDoesNotClearCurrentHTMLPresentationState() throws {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        let htmlURL = try makeTempFileURL(ext: "html")
        defer { try? FileManager.default.removeItem(at: htmlURL) }

        viewModel.outputWindowControllerFactory = { outputSpy }
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.switchToProgram(htmlItem)

        viewModel.handleBroadcastToggle()
        viewModel.handleBroadcastToggle()

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 1)
    }

    func testBroadcastToggleCycleDoesNotClearCurrentActiveDeckPresentationState() {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        var presentFrontDeckInvocationCount = 0

        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.activeDeckPresentationHandler = {
            presentFrontDeckInvocationCount += 1
        }
        viewModel.switchToProgram(activeDeckItem)

        viewModel.handleBroadcastToggle()
        viewModel.handleBroadcastToggle()

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 1)
    }

    func testBroadcastToggleCycleDoesNotInterruptCurrentVideoPlaybackState() throws {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.outputWindowControllerFactory = { outputSpy }
        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        viewModel.switchToProgram(videoItem)

        viewModel.handleBroadcastToggle()
        viewModel.handleBroadcastToggle()

        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertFalse(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 1)
    }

    func testShowOutputWindowReusesExistingControllerAcrossMultipleShows() {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        var factoryInvocationCount = 0

        viewModel.outputWindowControllerFactory = {
            factoryInvocationCount += 1
            return outputSpy
        }

        viewModel.showOutputWindow()
        viewModel.showOutputWindow()

        XCTAssertEqual(factoryInvocationCount, 1)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 2)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }

    func testSwitchingToKeynoteStopsPreviousVideoAndInvokesPresentationHandler() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let keynoteURL = try makeTempFileURL(ext: "key")
        let htmlURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: keynoteURL)
            try? FileManager.default.removeItem(at: htmlURL)
        }

        var presentedURL: URL?
        viewModel.keynotePresentationHandler = { url in
            presentedURL = url
        }

        let videoItem = ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL)
        let keynoteItem = ProgramItem(title: "主持稿", subtitle: "KEY", sourceURL: keynoteURL)

        viewModel.currentHTMLURL = htmlURL
        viewModel.switchToProgram(videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(keynoteItem)

        XCTAssertEqual(viewModel.currentProgramItem, keynoteItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(presentedURL, keynoteURL)
    }

    func testSwitchingToInvalidKeynoteDoesNotInterruptCurrentPlayback() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let invalidKeynoteURL = try makeEmptyTempFileURL(ext: "key")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: invalidKeynoteURL)
        }

        var presentedURL: URL?
        var invalidDeckAlertURL: URL?
        viewModel.keynotePresentationHandler = { url in
            presentedURL = url
        }
        viewModel.invalidDeckHandler = { url in
            invalidDeckAlertURL = url
        }

        let videoItem = ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL)
        let invalidKeynoteItem = ProgramItem(title: "损坏主持稿", subtitle: "KEY", sourceURL: invalidKeynoteURL)

        viewModel.switchToProgram(videoItem)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(invalidKeynoteItem)

        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertNil(presentedURL)
        XCTAssertEqual(invalidDeckAlertURL, invalidKeynoteURL)
    }

    func testSwitchingToEmptyKeynotePackageDoesNotInterruptCurrentPlayback() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let emptyKeynotePackageURL = try makeTempDirectoryURL(ext: "keynote")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: emptyKeynotePackageURL)
        }

        var presentedURL: URL?
        var invalidDeckAlertURL: URL?
        viewModel.keynotePresentationHandler = { url in
            presentedURL = url
        }
        viewModel.invalidDeckHandler = { url in
            invalidDeckAlertURL = url
        }

        let videoItem = ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL)
        let emptyPackageItem = ProgramItem(title: "空包 Keynote", subtitle: "KEY", sourceURL: emptyKeynotePackageURL)

        viewModel.switchToProgram(videoItem)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(emptyPackageItem)

        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertNil(presentedURL)
        XCTAssertEqual(invalidDeckAlertURL, emptyKeynotePackageURL)
    }

    func testSwitchingToInvalidPPTXDoesNotInterruptCurrentPlayback() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let invalidPPTXURL = try makeEmptyTempFileURL(ext: "pptx")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: invalidPPTXURL)
        }

        var openedURL: URL?
        var invalidDeckAlertURL: URL?
        viewModel.pptxOpenHandler = { url in
            openedURL = url
        }
        viewModel.invalidDeckHandler = { url in
            invalidDeckAlertURL = url
        }

        let videoItem = ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL)
        let invalidPPTXItem = ProgramItem(title: "损坏流程稿", subtitle: "PPTX", sourceURL: invalidPPTXURL)

        viewModel.switchToProgram(videoItem)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(invalidPPTXItem)

        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertNil(openedURL)
        XCTAssertEqual(invalidDeckAlertURL, invalidPPTXURL)
    }

    func testSwitchingToDirectoryPPTXDoesNotInterruptCurrentPlayback() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let directoryPPTXURL = try makeTempDirectoryURL(ext: "pptx")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: directoryPPTXURL)
        }

        var openedURL: URL?
        var invalidDeckAlertURL: URL?
        viewModel.pptxOpenHandler = { url in
            openedURL = url
        }
        viewModel.invalidDeckHandler = { url in
            invalidDeckAlertURL = url
        }

        let videoItem = ProgramItem(title: "开场视频", subtitle: "MP4", sourceURL: videoURL)
        let directoryPPTXItem = ProgramItem(title: "误导入目录", subtitle: "PPTX", sourceURL: directoryPPTXURL)

        viewModel.switchToProgram(videoItem)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(directoryPPTXItem)

        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertNil(openedURL)
        XCTAssertEqual(invalidDeckAlertURL, directoryPPTXURL)
    }

    func testSwitchingToPPTXStopsPreviousVideoAndInvokesOpenHandler() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let pptxURL = try makeTempFileURL(ext: "pptx")
        let htmlURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: pptxURL)
            try? FileManager.default.removeItem(at: htmlURL)
        }

        var openedURL: URL?
        viewModel.pptxOpenHandler = { url in
            openedURL = url
        }

        let videoItem = ProgramItem(title: "宣传片", subtitle: "MP4", sourceURL: videoURL)
        let pptxItem = ProgramItem(title: "流程稿", subtitle: "PPTX", sourceURL: pptxURL)

        viewModel.currentHTMLURL = htmlURL
        viewModel.switchToProgram(videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(pptxItem)

        XCTAssertEqual(viewModel.currentProgramItem, pptxItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(openedURL, pptxURL)
    }

    func testSwitchingToVideoClearsHTMLAndStartsPlayback() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let htmlURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: htmlURL)
        }

        viewModel.isBroadcasting = true
        viewModel.currentHTMLURL = htmlURL

        let videoItem = ProgramItem(title: "开场片头", subtitle: "MP4", sourceURL: videoURL)
        viewModel.switchToProgram(videoItem)

        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
    }

    func testSwitchingToHTMLStopsVideoAndPromotesHTMLAsCurrentProgram() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let htmlURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: htmlURL)
        }

        let videoItem = ProgramItem(title: "宣传片", subtitle: "MP4", sourceURL: videoURL)
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)

        viewModel.isBroadcasting = true
        viewModel.switchToProgram(videoItem)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(htmlItem)

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
    }

    func testSwitchingToUnsupportedProgramDoesNotMutateCurrentOutputState() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        let unsupportedURL = try makeTempFileURL(ext: "txt")
        defer {
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: unsupportedURL)
        }

        let currentItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.switchToProgram(currentItem)
        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)

        let unsupportedItem = ProgramItem(title: "说明文档", subtitle: "TXT", sourceURL: unsupportedURL)
        viewModel.switchToProgram(unsupportedItem)

        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }

    func testSwitchingToMissingMediaFileDoesNotReplaceCurrentProgram() throws {
        let viewModel = makeViewModel()
        let currentURL = try makeTempFileURL(ext: "mp4")
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        defer { try? FileManager.default.removeItem(at: currentURL) }

        let currentItem = ProgramItem(title: "当前片头", subtitle: "MP4", sourceURL: currentURL)
        let missingItem = ProgramItem(title: "已移动文件", subtitle: "MP4", sourceURL: missingURL)

        viewModel.switchToProgram(currentItem)
        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, currentURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(missingItem)

        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, currentURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.supportEvents.last?.kind, .programItemFileMissing)
        XCTAssertTrue(viewModel.supportEvents.last?.detail.contains("sourceKind=media") == true)
        XCTAssertFalse(viewModel.supportEvents.last?.detail.contains(missingURL.lastPathComponent) == true)
        XCTAssertEqual(viewModel.automationRuntimeNotice?.title, "节目文件不存在")
    }

    func testSwitchingToMissingHTMLFileDoesNotPromoteCurrentHTML() throws {
        let viewModel = makeViewModel()
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")
        let missingItem = ProgramItem(title: "已删除签到页", subtitle: "HTML", sourceURL: missingURL)

        viewModel.switchToProgram(missingItem)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.supportEvents.last?.kind, .programItemFileMissing)
        XCTAssertTrue(viewModel.supportEvents.last?.detail.contains("sourceKind=html") == true)
        XCTAssertEqual(viewModel.automationRuntimeNotice?.title, "节目文件不存在")
    }

    func testSwitchingToMissingPPTXFileDoesNotInvokeOpenHandler() throws {
        let viewModel = makeViewModel()
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pptx")
        let missingItem = ProgramItem(title: "已删除流程稿", subtitle: "PPTX", sourceURL: missingURL)
        var openedURL: URL?
        viewModel.pptxOpenHandler = { openedURL = $0 }

        viewModel.switchToProgram(missingItem)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertNil(openedURL)
        XCTAssertEqual(viewModel.supportEvents.last?.kind, .programItemFileMissing)
        XCTAssertTrue(viewModel.supportEvents.last?.detail.contains("sourceKind=pptx") == true)
        XCTAssertEqual(viewModel.automationRuntimeNotice?.title, "节目文件不存在")
    }

    func testSwitchingFromVideoToHTMLWhileBroadcastingDoesNotReopenOutputWindow() throws {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let htmlURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: htmlURL)
        }

        viewModel.outputWindowControllerFactory = { outputSpy }
        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)

        viewModel.switchToProgram(videoItem)
        viewModel.handleBroadcastToggle()
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)

        viewModel.switchToProgram(htmlItem)

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }

    func testSwitchingFromHTMLToVideoWhileBroadcastingDoesNotReopenOutputWindow() throws {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        let htmlURL = try makeTempFileURL(ext: "html")
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: videoURL)
        }

        viewModel.outputWindowControllerFactory = { outputSpy }
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)

        viewModel.switchToProgram(htmlItem)
        viewModel.handleBroadcastToggle()
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)

        viewModel.switchToProgram(videoItem)

        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }

    func testEndingHTMLClearsProgramAndFallsBackToWallpaperState() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        let wallpaperURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: wallpaperURL)
        }

        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.setActiveWallpaper(url: wallpaperURL)
        let htmlItem = ProgramItem(title: "主视觉", subtitle: "HTML", sourceURL: htmlURL)

        viewModel.isBroadcasting = true
        viewModel.switchToProgram(htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNotNil(viewModel.backgroundImage)

        viewModel.endHTMLPresentation()

        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertTrue(viewModel.isBroadcasting)
    }

    func testEndingHTMLWhileBroadcastingDoesNotHideOutputWindow() throws {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        let htmlURL = try makeTempFileURL(ext: "html")
        let wallpaperURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: wallpaperURL)
        }

        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.setActiveWallpaper(url: wallpaperURL)
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)

        viewModel.switchToProgram(htmlItem)
        viewModel.handleBroadcastToggle()

        viewModel.endHTMLPresentation()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }

    func testRepeatedEndingHTMLWhileBroadcastingIsIdempotent() throws {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        let htmlURL = try makeTempFileURL(ext: "html")
        let wallpaperURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: wallpaperURL)
        }

        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.setActiveWallpaper(url: wallpaperURL)
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)

        viewModel.switchToProgram(htmlItem)
        viewModel.handleBroadcastToggle()

        viewModel.endHTMLPresentation()
        viewModel.endHTMLPresentation()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }

    func testRemovingCurrentProgramClearsPlaybackAndListState() throws {
        let viewModel = makeViewModel()
        let currentVideoURL = try makeTempFileURL(ext: "mp4")
        let standbyVideoURL = try makeTempFileURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: currentVideoURL)
            try? FileManager.default.removeItem(at: standbyVideoURL)
        }

        let currentItem = ProgramItem(title: "当前节目", subtitle: "MP4", sourceURL: currentVideoURL)
        let standbyItem = ProgramItem(title: "备用节目", subtitle: "MP4", sourceURL: standbyVideoURL)
        viewModel.addProgramItem(currentItem)
        viewModel.addProgramItem(standbyItem)
        viewModel.switchToProgram(currentItem)

        viewModel.removeProgramItem(withID: currentItem.id)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.programItems.count, 1)
        XCTAssertEqual(viewModel.programItems.first, standbyItem)
    }

    func testRemovingCurrentHTMLProgramClearsHTMLAndReturnsToIdleState() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        let standbyVideoURL = try makeTempFileURL(ext: "mp4")
        let wallpaperURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: standbyVideoURL)
            try? FileManager.default.removeItem(at: wallpaperURL)
        }

        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.setActiveWallpaper(url: wallpaperURL)

        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        let standbyItem = ProgramItem(title: "备用片头", subtitle: "MP4", sourceURL: standbyVideoURL)
        viewModel.addProgramItem(htmlItem)
        viewModel.addProgramItem(standbyItem)
        viewModel.isBroadcasting = true
        viewModel.switchToProgram(htmlItem)

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)

        viewModel.removeProgramItem(withID: htmlItem.id)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertEqual(viewModel.programItems, [standbyItem])
        XCTAssertTrue(viewModel.isBroadcasting)
    }

    func testRemovingCurrentVideoWhileBroadcastingDoesNotHideOutputWindow() throws {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.outputWindowControllerFactory = { outputSpy }
        let videoItem = ProgramItem(title: "当前节目", subtitle: "MP4", sourceURL: videoURL)
        viewModel.addProgramItem(videoItem)
        viewModel.switchToProgram(videoItem)
        viewModel.handleBroadcastToggle()

        viewModel.removeProgramItem(withID: videoItem.id)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }

    func testRemovingCurrentHTMLWhileBroadcastingDoesNotHideOutputWindow() throws {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        let htmlURL = try makeTempFileURL(ext: "html")
        defer { try? FileManager.default.removeItem(at: htmlURL) }

        viewModel.outputWindowControllerFactory = { outputSpy }
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.addProgramItem(htmlItem)
        viewModel.switchToProgram(htmlItem)
        viewModel.handleBroadcastToggle()

        viewModel.removeProgramItem(withID: htmlItem.id)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }

    func testRepeatedRemovalOfCurrentHTMLWhileBroadcastingIsIdempotent() throws {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        let htmlURL = try makeTempFileURL(ext: "html")
        defer { try? FileManager.default.removeItem(at: htmlURL) }

        viewModel.outputWindowControllerFactory = { outputSpy }
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.addProgramItem(htmlItem)
        viewModel.switchToProgram(htmlItem)
        viewModel.handleBroadcastToggle()

        viewModel.removeProgramItem(withID: htmlItem.id)
        viewModel.removeProgramItem(withID: htmlItem.id)

        XCTAssertTrue(viewModel.programItems.isEmpty)
        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }

    func testToggleMainVideoPlaybackPausesAndResumesCurrentVideo() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        viewModel.switchToProgram(videoItem)

        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)

        viewModel.toggleMainVideoPlayback()
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)

        viewModel.toggleMainVideoPlayback()
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
    }

    func testToggleMainVideoPlaybackIsNoOpForCurrentHTMLProgram() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        defer { try? FileManager.default.removeItem(at: htmlURL) }

        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.switchToProgram(htmlItem)

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)

        viewModel.toggleMainVideoPlayback()

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }

    func testToggleMainVideoPlaybackIsNoOpWithoutCurrentProgram() {
        let viewModel = makeViewModel()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)

        viewModel.toggleMainVideoPlayback()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }

    func testToggleMainVideoPlaybackForDeckProgramInvokesDeckStopHandler() throws {
        let viewModel = makeViewModel()
        let keynoteURL = try makeTempFileURL(ext: "key")
        defer { try? FileManager.default.removeItem(at: keynoteURL) }

        let keynoteItem = ProgramItem(title: "主持稿", subtitle: "KEY", sourceURL: keynoteURL)
        var stopInvocationCount = 0
        viewModel.deckStopHandler = {
            stopInvocationCount += 1
        }

        viewModel.currentProgramItem = keynoteItem
        viewModel.toggleMainVideoPlayback()

        XCTAssertEqual(stopInvocationCount, 1)
        XCTAssertEqual(viewModel.currentProgramItem, keynoteItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }

    func testToggleMainVideoPlaybackForActiveDeckWithoutSourceInvokesDeckStopHandler() {
        let viewModel = makeViewModel()
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        var stopInvocationCount = 0
        viewModel.deckStopHandler = {
            stopInvocationCount += 1
        }

        viewModel.currentProgramItem = activeDeckItem
        viewModel.toggleMainVideoPlayback()

        XCTAssertEqual(stopInvocationCount, 1)
        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
    }

    func testTogglePauseSwitchesToRequestedProgramWhenItemIsNotCurrent() throws {
        let viewModel = makeViewModel()
        let currentVideoURL = try makeTempFileURL(ext: "mp4")
        let targetVideoURL = try makeTempFileURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: currentVideoURL)
            try? FileManager.default.removeItem(at: targetVideoURL)
        }

        let currentItem = ProgramItem(title: "当前节目", subtitle: "MP4", sourceURL: currentVideoURL)
        let targetItem = ProgramItem(title: "目标节目", subtitle: "MP4", sourceURL: targetVideoURL)

        viewModel.switchToProgram(currentItem)
        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, currentVideoURL)

        viewModel.togglePause(for: targetItem)

        XCTAssertEqual(viewModel.currentProgramItem, targetItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, targetVideoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
    }

    func testTogglePauseProgramSwitchWhileBroadcastingDoesNotReopenOutputWindow() throws {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        let currentVideoURL = try makeTempFileURL(ext: "mp4")
        let targetHTMLURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: currentVideoURL)
            try? FileManager.default.removeItem(at: targetHTMLURL)
        }

        viewModel.outputWindowControllerFactory = { outputSpy }
        let currentItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: currentVideoURL)
        let targetItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: targetHTMLURL)

        viewModel.switchToProgram(currentItem)
        viewModel.handleBroadcastToggle()
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)

        viewModel.togglePause(for: targetItem)

        XCTAssertEqual(viewModel.currentProgramItem, targetItem)
        XCTAssertEqual(viewModel.currentHTMLURL, targetHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }

    func testTogglePauseForCurrentProgramTogglesPlaybackState() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        viewModel.switchToProgram(videoItem)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.togglePause(for: videoItem)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)

        viewModel.togglePause(for: videoItem)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
    }

    func testTogglePauseForCurrentHTMLProgramIsNoOp() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        defer { try? FileManager.default.removeItem(at: htmlURL) }

        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.switchToProgram(htmlItem)

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)

        viewModel.togglePause(for: htmlItem)

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }

    func testTogglePauseForCurrentActiveDeckInvokesDeckStopHandler() {
        let viewModel = makeViewModel()
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        var stopInvocationCount = 0
        viewModel.deckStopHandler = {
            stopInvocationCount += 1
        }

        viewModel.currentProgramItem = activeDeckItem

        viewModel.togglePause(for: activeDeckItem)

        XCTAssertEqual(stopInvocationCount, 1)
        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }

    func testTogglePauseForCurrentDeckProgramInvokesDeckStopHandler() throws {
        let viewModel = makeViewModel()
        let keynoteURL = try makeTempFileURL(ext: "key")
        defer { try? FileManager.default.removeItem(at: keynoteURL) }

        let keynoteItem = ProgramItem(title: "主持稿", subtitle: "KEY", sourceURL: keynoteURL)
        var stopInvocationCount = 0
        viewModel.deckStopHandler = {
            stopInvocationCount += 1
        }

        viewModel.currentProgramItem = keynoteItem

        viewModel.togglePause(for: keynoteItem)

        XCTAssertEqual(stopInvocationCount, 1)
        XCTAssertEqual(viewModel.currentProgramItem, keynoteItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }

    func testTogglePauseSwitchesToActiveDeckWithoutSourceWhenItemIsNotCurrent() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        var presentFrontDeckInvocationCount = 0
        viewModel.activeDeckPresentationHandler = {
            presentFrontDeckInvocationCount += 1
        }

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)

        viewModel.switchToProgram(videoItem)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.togglePause(for: activeDeckItem)

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
    }

    func testTogglePauseSwitchesFromCurrentHTMLToDifferentHTMLProgram() throws {
        let viewModel = makeViewModel()
        let firstHTMLURL = try makeTempFileURL(ext: "html")
        let secondHTMLURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: firstHTMLURL)
            try? FileManager.default.removeItem(at: secondHTMLURL)
        }

        let currentItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: firstHTMLURL)
        let targetItem = ProgramItem(title: "主视觉", subtitle: "HTML", sourceURL: secondHTMLURL)

        viewModel.switchToProgram(currentItem)
        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertEqual(viewModel.currentHTMLURL, firstHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)

        viewModel.togglePause(for: targetItem)

        XCTAssertEqual(viewModel.currentProgramItem, targetItem)
        XCTAssertEqual(viewModel.currentHTMLURL, secondHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }

    func testTogglePauseSwitchesFromCurrentHTMLToDeckProgram() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        let keynoteURL = try makeTempFileURL(ext: "key")
        defer {
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: keynoteURL)
        }

        var presentedURL: URL?
        viewModel.keynotePresentationHandler = { url in
            presentedURL = url
        }

        let currentItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        let targetItem = ProgramItem(title: "主持稿", subtitle: "KEY", sourceURL: keynoteURL)

        viewModel.switchToProgram(currentItem)
        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)

        viewModel.togglePause(for: targetItem)

        XCTAssertEqual(viewModel.currentProgramItem, targetItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(presentedURL, keynoteURL)
    }

    func testTogglePauseSwitchesFromCurrentDeckToHTMLProgram() throws {
        let viewModel = makeViewModel()
        let keynoteURL = try makeTempFileURL(ext: "key")
        let htmlURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: keynoteURL)
            try? FileManager.default.removeItem(at: htmlURL)
        }

        var presentedURL: URL?
        viewModel.keynotePresentationHandler = { url in
            presentedURL = url
        }

        let currentItem = ProgramItem(title: "主持稿", subtitle: "KEY", sourceURL: keynoteURL)
        let targetItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)

        viewModel.switchToProgram(currentItem)
        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(presentedURL, keynoteURL)

        viewModel.togglePause(for: targetItem)

        XCTAssertEqual(viewModel.currentProgramItem, targetItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }

    func testSwitchToProgramAtUsesIndexedProgramItemAndIgnoresInvalidIndex() throws {
        let viewModel = makeViewModel()
        let firstURL = try makeTempFileURL(ext: "mp4")
        let secondURL = try makeTempFileURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }

        let firstItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: firstURL)
        let secondItem = ProgramItem(title: "正片", subtitle: "MP4", sourceURL: secondURL)
        viewModel.addProgramItem(firstItem)
        viewModel.addProgramItem(secondItem)

        viewModel.switchToProgram(at: 1)

        XCTAssertEqual(viewModel.currentProgramItem, secondItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, secondURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(at: 9)
        XCTAssertEqual(viewModel.currentProgramItem, secondItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, secondURL)

        viewModel.switchToProgram(at: -1)
        XCTAssertEqual(viewModel.currentProgramItem, secondItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, secondURL)
    }

    func testSwitchToProgramAtInvalidIndexDoesNotInterruptCurrentHTMLPresentation() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        defer { try? FileManager.default.removeItem(at: htmlURL) }

        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.addProgramItem(htmlItem)
        viewModel.isBroadcasting = true
        viewModel.switchToProgram(htmlItem)

        viewModel.switchToProgram(at: 9)

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
    }

    func testSwitchToProgramAtInvalidIndexDoesNotInterruptCurrentActiveDeckPresentation() {
        let viewModel = makeViewModel()
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        var presentFrontDeckInvocationCount = 0
        viewModel.activeDeckPresentationHandler = {
            presentFrontDeckInvocationCount += 1
        }

        viewModel.addProgramItem(activeDeckItem)
        viewModel.switchToProgram(activeDeckItem)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)

        viewModel.switchToProgram(at: 2)

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
    }

    func testSwitchToProgramAtInvalidIndexIsNoOpWhenProgramListIsEmpty() {
        let viewModel = makeViewModel()

        XCTAssertTrue(viewModel.programItems.isEmpty)
        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(at: 0)

        XCTAssertTrue(viewModel.programItems.isEmpty)
        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }

    func testSeekProgramItemToStartOnlyTargetsCurrentProgram() throws {
        let viewModel = makeViewModel()
        let currentURL = try makeTempFileURL(ext: "mp4")
        let otherURL = try makeTempFileURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: currentURL)
            try? FileManager.default.removeItem(at: otherURL)
        }

        let currentItem = ProgramItem(title: "当前节目", subtitle: "MP4", sourceURL: currentURL)
        let otherItem = ProgramItem(title: "其他节目", subtitle: "MP4", sourceURL: otherURL)
        var seekToStartCount = 0
        viewModel.programSeekToStartHandler = {
            seekToStartCount += 1
        }

        viewModel.switchToProgram(currentItem)
        viewModel.seekProgramItemToStart(otherItem)
        XCTAssertEqual(seekToStartCount, 0)

        viewModel.seekProgramItemToStart(currentItem)
        XCTAssertEqual(seekToStartCount, 1)
        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
    }

    func testSeekProgramItemToEndOnlyTargetsCurrentProgram() throws {
        let viewModel = makeViewModel()
        let currentURL = try makeTempFileURL(ext: "mp4")
        let otherURL = try makeTempFileURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: currentURL)
            try? FileManager.default.removeItem(at: otherURL)
        }

        let currentItem = ProgramItem(title: "当前节目", subtitle: "MP4", sourceURL: currentURL)
        let otherItem = ProgramItem(title: "其他节目", subtitle: "MP4", sourceURL: otherURL)
        var seekToEndCount = 0
        viewModel.programSeekToEndHandler = {
            seekToEndCount += 1
        }

        viewModel.switchToProgram(currentItem)
        viewModel.seekProgramItemToEnd(otherItem)
        XCTAssertEqual(seekToEndCount, 0)

        viewModel.seekProgramItemToEnd(currentItem)
        XCTAssertEqual(seekToEndCount, 1)
        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
    }

    func testSeekProgramItemToStartIsNoOpForCurrentHTMLProgram() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        defer { try? FileManager.default.removeItem(at: htmlURL) }

        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        var seekToStartCount = 0
        viewModel.programSeekToStartHandler = {
            seekToStartCount += 1
        }

        viewModel.switchToProgram(htmlItem)
        viewModel.seekProgramItemToStart(htmlItem)

        XCTAssertEqual(seekToStartCount, 0)
        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
    }

    func testSeekProgramItemToEndIsNoOpForCurrentDeckProgram() throws {
        let viewModel = makeViewModel()
        let keynoteURL = try makeTempFileURL(ext: "key")
        defer { try? FileManager.default.removeItem(at: keynoteURL) }

        let keynoteItem = ProgramItem(title: "主持稿", subtitle: "KEY", sourceURL: keynoteURL)
        var seekToEndCount = 0
        viewModel.programSeekToEndHandler = {
            seekToEndCount += 1
        }
        viewModel.keynotePresentationHandler = { _ in }

        viewModel.switchToProgram(keynoteItem)
        viewModel.seekProgramItemToEnd(keynoteItem)

        XCTAssertEqual(seekToEndCount, 0)
        XCTAssertEqual(viewModel.currentProgramItem, keynoteItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }

    func testRemovingNonCurrentProgramDoesNotInterruptCurrentPlayback() throws {
        let viewModel = makeViewModel()
        let currentURL = try makeTempFileURL(ext: "mp4")
        let otherURL = try makeTempFileURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: currentURL)
            try? FileManager.default.removeItem(at: otherURL)
        }

        let currentItem = ProgramItem(title: "当前节目", subtitle: "MP4", sourceURL: currentURL)
        let otherItem = ProgramItem(title: "待删节目", subtitle: "MP4", sourceURL: otherURL)
        viewModel.addProgramItem(currentItem)
        viewModel.addProgramItem(otherItem)
        viewModel.switchToProgram(currentItem)

        viewModel.removeProgramItem(withID: otherItem.id)

        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, currentURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.programItems, [currentItem])
    }

    func testRemovingUnknownProgramIDDoesNotInterruptCurrentHTMLPresentation() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        defer { try? FileManager.default.removeItem(at: htmlURL) }

        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.addProgramItem(htmlItem)
        viewModel.isBroadcasting = true
        viewModel.switchToProgram(htmlItem)

        viewModel.removeProgramItem(withID: UUID())

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.programItems, [htmlItem])
        XCTAssertTrue(viewModel.isBroadcasting)
    }

    func testRemovingNonCurrentHTMLProgramDoesNotInterruptCurrentVideoPlayback() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let htmlURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: htmlURL)
        }

        let currentItem = ProgramItem(title: "当前节目", subtitle: "MP4", sourceURL: videoURL)
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.addProgramItem(currentItem)
        viewModel.addProgramItem(htmlItem)
        viewModel.switchToProgram(currentItem)

        viewModel.removeProgramItem(withID: htmlItem.id)

        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.programItems, [currentItem])
    }

    func testRemovingNonCurrentDeckProgramDoesNotInterruptCurrentHTMLPresentation() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        let keynoteURL = try makeTempFileURL(ext: "key")
        defer {
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: keynoteURL)
        }

        let currentItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        let deckItem = ProgramItem(title: "主持稿", subtitle: "KEY", sourceURL: keynoteURL)
        viewModel.addProgramItem(currentItem)
        viewModel.addProgramItem(deckItem)
        viewModel.isBroadcasting = true
        viewModel.switchToProgram(currentItem)

        viewModel.removeProgramItem(withID: deckItem.id)

        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.programItems, [currentItem])
        XCTAssertTrue(viewModel.isBroadcasting)
    }

    func testRemovingCurrentActiveDeckItemReturnsToIdleState() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        viewModel.addProgramItem(activeDeckItem)
        viewModel.addProgramItem(videoItem)

        viewModel.switchToProgram(activeDeckItem)
        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.avCoordinator.currentURL)

        viewModel.removeProgramItem(withID: activeDeckItem.id)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.programItems, [videoItem])
    }

    func testRemovingCurrentActiveDeckStopsDeckPresentation() throws {
        let viewModel = makeViewModel()
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        var presentFrontDeckInvocationCount = 0
        var stopInvocationCount = 0
        viewModel.activeDeckPresentationHandler = {
            presentFrontDeckInvocationCount += 1
        }
        viewModel.deckStopHandler = {
            stopInvocationCount += 1
        }
        viewModel.addProgramItem(activeDeckItem)
        viewModel.switchToProgram(activeDeckItem)

        viewModel.removeProgramItem(withID: activeDeckItem.id)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
        XCTAssertEqual(stopInvocationCount, 1)
    }

    func testRemovingCurrentActiveDeckWhileBroadcastingDoesNotHideOutputWindow() throws {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.outputWindowControllerFactory = { outputSpy }
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        let standbyVideoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        viewModel.addProgramItem(activeDeckItem)
        viewModel.addProgramItem(standbyVideoItem)
        viewModel.switchToProgram(activeDeckItem)
        viewModel.handleBroadcastToggle()

        viewModel.removeProgramItem(withID: activeDeckItem.id)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(viewModel.programItems, [standbyVideoItem])
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }

    func testRemovingCurrentVideoThenInvalidIndexKeepsIdleState() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        viewModel.addProgramItem(videoItem)
        viewModel.switchToProgram(videoItem)

        viewModel.removeProgramItem(withID: videoItem.id)
        viewModel.switchToProgram(at: 0)

        XCTAssertTrue(viewModel.programItems.isEmpty)
        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }

    func testRemovingCurrentHTMLThenInvalidIndexKeepsWallpaperFallbackState() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        let wallpaperURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: wallpaperURL)
        }

        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.setActiveWallpaper(url: wallpaperURL)

        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.addProgramItem(htmlItem)
        viewModel.isBroadcasting = true
        viewModel.switchToProgram(htmlItem)

        viewModel.removeProgramItem(withID: htmlItem.id)
        viewModel.switchToProgram(at: 0)

        XCTAssertTrue(viewModel.programItems.isEmpty)
        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertTrue(viewModel.isBroadcasting)
    }

    func testMoveProgramItemsDoesNotInterruptCurrentProgramState() throws {
        let viewModel = makeViewModel()
        let firstURL = try makeTempFileURL(ext: "mp4")
        let secondURL = try makeTempFileURL(ext: "mp4")
        let thirdURL = try makeTempFileURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
            try? FileManager.default.removeItem(at: thirdURL)
        }

        let firstItem = ProgramItem(title: "A", subtitle: "MP4", sourceURL: firstURL)
        let secondItem = ProgramItem(title: "B", subtitle: "MP4", sourceURL: secondURL)
        let thirdItem = ProgramItem(title: "C", subtitle: "MP4", sourceURL: thirdURL)
        viewModel.addProgramItem(firstItem)
        viewModel.addProgramItem(secondItem)
        viewModel.addProgramItem(thirdItem)

        viewModel.switchToProgram(secondItem)
        XCTAssertEqual(viewModel.currentProgramItem, secondItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, secondURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.moveProgramItems(from: IndexSet(integer: 2), to: 0)

        XCTAssertEqual(viewModel.currentProgramItem, secondItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, secondURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.programItems, [thirdItem, firstItem, secondItem])
    }

    func testMoveProgramItemsDoesNotInterruptCurrentHTMLPresentationState() throws {
        let viewModel = makeViewModel()
        let htmlURL = try makeTempFileURL(ext: "html")
        let videoURL = try makeTempFileURL(ext: "mp4")
        let secondHTMLURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: secondHTMLURL)
        }

        let currentItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        let middleItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let lastItem = ProgramItem(title: "主视觉", subtitle: "HTML", sourceURL: secondHTMLURL)
        viewModel.addProgramItem(currentItem)
        viewModel.addProgramItem(middleItem)
        viewModel.addProgramItem(lastItem)
        viewModel.isBroadcasting = true
        viewModel.switchToProgram(currentItem)

        viewModel.moveProgramItems(from: IndexSet(integer: 2), to: 0)

        XCTAssertEqual(viewModel.currentProgramItem, currentItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(viewModel.programItems, [lastItem, currentItem, middleItem])
    }

    func testMoveProgramItemsDoesNotInterruptCurrentActiveDeckPresentationState() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        var presentFrontDeckInvocationCount = 0
        viewModel.activeDeckPresentationHandler = {
            presentFrontDeckInvocationCount += 1
        }

        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let standbyDeckItem = ProgramItem(title: "副主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        viewModel.addProgramItem(activeDeckItem)
        viewModel.addProgramItem(videoItem)
        viewModel.addProgramItem(standbyDeckItem)
        viewModel.isBroadcasting = true
        viewModel.switchToProgram(activeDeckItem)

        viewModel.moveProgramItems(from: IndexSet(integer: 2), to: 0)

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
        XCTAssertEqual(viewModel.programItems, [standbyDeckItem, activeDeckItem, videoItem])
    }

    func testSwitchToProgramAtSupportsHTMLBranch() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let htmlURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: htmlURL)
        }

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.addProgramItem(videoItem)
        viewModel.addProgramItem(htmlItem)

        viewModel.switchToProgram(at: 0)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(at: 1)

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }

    func testSwitchToProgramAtSupportsDeckBranch() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let keynoteURL = try makeTempFileURL(ext: "key")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: keynoteURL)
        }

        var presentedURL: URL?
        viewModel.keynotePresentationHandler = { url in
            presentedURL = url
        }

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let keynoteItem = ProgramItem(title: "主持稿", subtitle: "KEY", sourceURL: keynoteURL)
        viewModel.addProgramItem(videoItem)
        viewModel.addProgramItem(keynoteItem)

        viewModel.switchToProgram(at: 0)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(at: 1)

        XCTAssertEqual(viewModel.currentProgramItem, keynoteItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(presentedURL, keynoteURL)
    }

    func testSwitchToProgramAtSupportsActiveDeckBranchWithoutSourceURL() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        var presentFrontDeckInvocationCount = 0
        viewModel.activeDeckPresentationHandler = {
            presentFrontDeckInvocationCount += 1
        }

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        viewModel.addProgramItem(videoItem)
        viewModel.addProgramItem(activeDeckItem)

        viewModel.switchToProgram(at: 0)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(at: 1)

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
    }

    func testSwitchToProgramAtWhileBroadcastingDoesNotReopenOutputWindowForHTMLBranch() throws {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let htmlURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: htmlURL)
        }

        viewModel.outputWindowControllerFactory = { outputSpy }
        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        viewModel.addProgramItem(videoItem)
        viewModel.addProgramItem(htmlItem)

        viewModel.switchToProgram(at: 0)
        viewModel.handleBroadcastToggle()
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)

        viewModel.switchToProgram(at: 1)

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }

    func testSwitchToProgramAtWhileBroadcastingDoesNotReopenOutputWindowForActiveDeckBranch() throws {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        var presentFrontDeckInvocationCount = 0
        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.activeDeckPresentationHandler = {
            presentFrontDeckInvocationCount += 1
        }

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        viewModel.addProgramItem(videoItem)
        viewModel.addProgramItem(activeDeckItem)

        viewModel.switchToProgram(at: 0)
        viewModel.handleBroadcastToggle()
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)

        viewModel.switchToProgram(at: 1)

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }

    func testSwitchingToActiveDeckItemWithoutSourceURLStopsPreviousVideo() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let htmlURL = try makeTempFileURL(ext: "html")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: htmlURL)
        }

        var presentFrontDeckInvocationCount = 0
        viewModel.activeDeckPresentationHandler = {
            presentFrontDeckInvocationCount += 1
        }

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)

        viewModel.currentHTMLURL = htmlURL
        viewModel.switchToProgram(videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.switchToProgram(activeDeckItem)

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
    }

    func testSwitchingFromVideoToActiveDeckWhileBroadcastingDoesNotReopenOutputWindow() throws {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        var presentFrontDeckInvocationCount = 0
        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.activeDeckPresentationHandler = {
            presentFrontDeckInvocationCount += 1
        }

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)

        viewModel.switchToProgram(videoItem)
        viewModel.handleBroadcastToggle()
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)

        viewModel.switchToProgram(activeDeckItem)

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }

    func testSwitchingFromActiveDeckToHTMLWhileBroadcastingDoesNotReopenOutputWindow() throws {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        let htmlURL = try makeTempFileURL(ext: "html")
        defer { try? FileManager.default.removeItem(at: htmlURL) }

        var presentFrontDeckInvocationCount = 0
        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.activeDeckPresentationHandler = {
            presentFrontDeckInvocationCount += 1
        }

        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)

        viewModel.switchToProgram(activeDeckItem)
        viewModel.handleBroadcastToggle()
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)

        viewModel.switchToProgram(htmlItem)

        XCTAssertEqual(viewModel.currentProgramItem, htmlItem)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }

    func testSwitchingAwayFromActiveDeckStopsDeckPresentation() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        let videoItem = ProgramItem(title: "返场视频", subtitle: "MP4", sourceURL: videoURL)
        var presentFrontDeckInvocationCount = 0
        var stopInvocationCount = 0
        viewModel.activeDeckPresentationHandler = {
            presentFrontDeckInvocationCount += 1
        }
        viewModel.deckStopHandler = {
            stopInvocationCount += 1
        }

        viewModel.switchToProgram(activeDeckItem)
        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)

        viewModel.switchToProgram(videoItem)

        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(stopInvocationCount, 1)
    }

    func testSelectingAgendaMarkerDoesNotStopCurrentActiveDeckPresentation() {
        let viewModel = makeViewModel()
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        let agendaMarker = ProgramItem.agendaMarker(title: "中场提醒")
        var presentFrontDeckInvocationCount = 0
        var stopInvocationCount = 0
        viewModel.activeDeckPresentationHandler = {
            presentFrontDeckInvocationCount += 1
        }
        viewModel.deckStopHandler = {
            stopInvocationCount += 1
        }

        viewModel.switchToProgram(activeDeckItem)
        viewModel.switchToProgram(agendaMarker)

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
        XCTAssertEqual(stopInvocationCount, 0)
    }

    func testInvalidKeynoteDoesNotStopCurrentActiveDeckPresentation() throws {
        let viewModel = makeViewModel()
        let invalidKeynoteURL = try makeEmptyTempFileURL(ext: "key")
        defer { try? FileManager.default.removeItem(at: invalidKeynoteURL) }

        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        let invalidKeynoteItem = ProgramItem(title: "空白 Keynote", subtitle: "KEY", sourceURL: invalidKeynoteURL)
        var presentFrontDeckInvocationCount = 0
        var stopInvocationCount = 0
        var invalidDeckURL: URL?
        viewModel.activeDeckPresentationHandler = {
            presentFrontDeckInvocationCount += 1
        }
        viewModel.deckStopHandler = {
            stopInvocationCount += 1
        }
        viewModel.invalidDeckHandler = { url in
            invalidDeckURL = url
        }

        viewModel.switchToProgram(activeDeckItem)
        viewModel.switchToProgram(invalidKeynoteItem)

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
        XCTAssertEqual(stopInvocationCount, 0)
        XCTAssertEqual(invalidDeckURL, invalidKeynoteURL)
    }

    func testEmptyKeynotePackageDoesNotStopCurrentActiveDeckPresentation() throws {
        let viewModel = makeViewModel()
        let emptyKeynotePackageURL = try makeTempDirectoryURL(ext: "keynote")
        defer { try? FileManager.default.removeItem(at: emptyKeynotePackageURL) }

        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        let emptyPackageItem = ProgramItem(title: "空包 Keynote", subtitle: "KEY", sourceURL: emptyKeynotePackageURL)
        var presentFrontDeckInvocationCount = 0
        var stopInvocationCount = 0
        var invalidDeckURL: URL?
        viewModel.activeDeckPresentationHandler = {
            presentFrontDeckInvocationCount += 1
        }
        viewModel.deckStopHandler = {
            stopInvocationCount += 1
        }
        viewModel.invalidDeckHandler = { url in
            invalidDeckURL = url
        }

        viewModel.switchToProgram(activeDeckItem)
        viewModel.switchToProgram(emptyPackageItem)

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
        XCTAssertEqual(stopInvocationCount, 0)
        XCTAssertEqual(invalidDeckURL, emptyKeynotePackageURL)
    }

    func testInvalidPPTXDoesNotStopCurrentActiveDeckPresentation() throws {
        let viewModel = makeViewModel()
        let invalidPPTXURL = try makeEmptyTempFileURL(ext: "pptx")
        defer { try? FileManager.default.removeItem(at: invalidPPTXURL) }

        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        let invalidPPTXItem = ProgramItem(title: "空白 PPT", subtitle: "PPTX", sourceURL: invalidPPTXURL)
        var presentFrontDeckInvocationCount = 0
        var stopInvocationCount = 0
        var invalidDeckURL: URL?
        viewModel.activeDeckPresentationHandler = {
            presentFrontDeckInvocationCount += 1
        }
        viewModel.deckStopHandler = {
            stopInvocationCount += 1
        }
        viewModel.invalidDeckHandler = { url in
            invalidDeckURL = url
        }

        viewModel.switchToProgram(activeDeckItem)
        viewModel.switchToProgram(invalidPPTXItem)

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
        XCTAssertEqual(stopInvocationCount, 0)
        XCTAssertEqual(invalidDeckURL, invalidPPTXURL)
    }

    func testDirectoryPPTXDoesNotStopCurrentActiveDeckPresentation() throws {
        let viewModel = makeViewModel()
        let directoryPPTXURL = try makeTempDirectoryURL(ext: "pptx")
        defer { try? FileManager.default.removeItem(at: directoryPPTXURL) }

        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        let directoryPPTXItem = ProgramItem(title: "误导入目录", subtitle: "PPTX", sourceURL: directoryPPTXURL)
        var presentFrontDeckInvocationCount = 0
        var stopInvocationCount = 0
        var invalidDeckURL: URL?
        viewModel.activeDeckPresentationHandler = {
            presentFrontDeckInvocationCount += 1
        }
        viewModel.deckStopHandler = {
            stopInvocationCount += 1
        }
        viewModel.invalidDeckHandler = { url in
            invalidDeckURL = url
        }

        viewModel.switchToProgram(activeDeckItem)
        viewModel.switchToProgram(directoryPPTXItem)

        XCTAssertEqual(viewModel.currentProgramItem, activeDeckItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
        XCTAssertEqual(stopInvocationCount, 0)
        XCTAssertEqual(invalidDeckURL, directoryPPTXURL)
    }

    func testMultiStepProgramSwitchWhileBroadcastingReusesSingleOutputWindowController() throws {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let htmlURL = try makeTempFileURL(ext: "html")
        let secondVideoURL = try makeTempFileURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: secondVideoURL)
        }

        var presentFrontDeckInvocationCount = 0
        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.activeDeckPresentationHandler = {
            presentFrontDeckInvocationCount += 1
        }

        let openingVideo = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        let closingVideo = ProgramItem(title: "片尾", subtitle: "MP4", sourceURL: secondVideoURL)

        viewModel.switchToProgram(openingVideo)
        viewModel.handleBroadcastToggle()
        viewModel.switchToProgram(htmlItem)
        viewModel.switchToProgram(activeDeckItem)
        viewModel.switchToProgram(closingVideo)

        XCTAssertEqual(viewModel.currentProgramItem, closingVideo)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, secondVideoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(presentFrontDeckInvocationCount, 1)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }

    func testPlaybackEndedAfterMultiStepProgramSwitchKeepsOutputWindowVisible() throws {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        let openingVideoURL = try makeTempFileURL(ext: "mp4")
        let htmlURL = try makeTempFileURL(ext: "html")
        let closingVideoURL = try makeTempFileURL(ext: "mp4")
        let wallpaperURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: openingVideoURL)
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: closingVideoURL)
            try? FileManager.default.removeItem(at: wallpaperURL)
        }

        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.setActiveWallpaper(url: wallpaperURL)

        let openingVideo = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: openingVideoURL)
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)
        let closingVideo = ProgramItem(title: "片尾", subtitle: "MP4", sourceURL: closingVideoURL)

        viewModel.switchToProgram(openingVideo)
        viewModel.handleBroadcastToggle()
        viewModel.switchToProgram(htmlItem)
        viewModel.switchToProgram(closingVideo)

        viewModel.avCoordinator.isPlaying = false
        viewModel.avCoordinator.didPlayToEnd = true
        viewModel.avCoordinator.onPlaybackEnded?()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.avCoordinator.didPlayToEnd)
        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }

    func testEndingHTMLAfterBroadcastedProgramSwitchKeepsOutputWindowVisible() throws {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let htmlURL = try makeTempFileURL(ext: "html")
        let wallpaperURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: wallpaperURL)
        }

        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.setActiveWallpaper(url: wallpaperURL)

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let htmlItem = ProgramItem(title: "签到页", subtitle: "HTML", sourceURL: htmlURL)

        viewModel.switchToProgram(videoItem)
        viewModel.handleBroadcastToggle()
        viewModel.switchToProgram(htmlItem)

        viewModel.endHTMLPresentation()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }

    func testRemovingCurrentActiveDeckAfterProgramSwitchKeepsOutputWindowVisible() throws {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.outputWindowControllerFactory = { outputSpy }
        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let activeDeckItem = ProgramItem(title: "主持稿", subtitle: "KEY (活动)", sourceURL: nil)
        viewModel.addProgramItem(videoItem)
        viewModel.addProgramItem(activeDeckItem)

        viewModel.switchToProgram(videoItem)
        viewModel.handleBroadcastToggle()
        viewModel.switchToProgram(activeDeckItem)

        viewModel.removeProgramItem(withID: activeDeckItem.id)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertNil(viewModel.avCoordinator.currentURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(viewModel.programItems, [videoItem])
        XCTAssertEqual(outputSpy.mountCount, 1)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }

    func testPlaybackEndedClearsCurrentProgramAndReturnsToWallpaper() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let wallpaperURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: wallpaperURL)
        }

        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.setActiveWallpaper(url: wallpaperURL)
        let videoItem = ProgramItem(title: "片尾视频", subtitle: "MP4", sourceURL: videoURL)

        viewModel.isBroadcasting = true
        viewModel.switchToProgram(videoItem)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)

        viewModel.avCoordinator.isPlaying = false
        viewModel.avCoordinator.didPlayToEnd = true
        viewModel.handlePlaybackEnded()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.avCoordinator.didPlayToEnd)
        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertTrue(viewModel.isBroadcasting)
    }

    func testPlaybackEndedAutoPlaysNextVideoOnlyWhenEnabled() throws {
        let viewModel = makeViewModel()
        let firstVideoURL = try makeTempFileURL(ext: "mp4")
        let secondVideoURL = try makeTempFileURL(ext: "mov")
        defer {
            try? FileManager.default.removeItem(at: firstVideoURL)
            try? FileManager.default.removeItem(at: secondVideoURL)
        }

        let firstVideo = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: firstVideoURL)
        let secondVideo = ProgramItem(title: "下一条", subtitle: "MOV", sourceURL: secondVideoURL)
        viewModel.addProgramItem(firstVideo)
        viewModel.addProgramItem(secondVideo)
        viewModel.autoPlayNextVideoOnEnd = true
        viewModel.switchToProgram(firstVideo)

        viewModel.avCoordinator.isPlaying = false
        viewModel.avCoordinator.didPlayToEnd = true
        viewModel.avCoordinator.onPlaybackEnded?()

        XCTAssertEqual(viewModel.currentProgramItem, secondVideo)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, secondVideoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertFalse(viewModel.avCoordinator.didPlayToEnd)
        XCTAssertNil(viewModel.currentHTMLURL)
    }

    func testPlaybackEndedWithMissingAutoNextVideoReturnsToIdleInsteadOfStaleCurrent() throws {
        let viewModel = makeViewModel()
        let firstVideoURL = try makeTempFileURL(ext: "mp4")
        let missingNextURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        defer { try? FileManager.default.removeItem(at: firstVideoURL) }

        let firstVideo = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: firstVideoURL)
        let missingNext = ProgramItem(title: "已移动下一条", subtitle: "MOV", sourceURL: missingNextURL)
        viewModel.addProgramItem(firstVideo)
        viewModel.addProgramItem(missingNext)
        viewModel.autoPlayNextVideoOnEnd = true
        viewModel.switchToProgram(firstVideo)

        viewModel.avCoordinator.isPlaying = false
        viewModel.avCoordinator.didPlayToEnd = true
        viewModel.avCoordinator.onPlaybackEnded?()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.avCoordinator.didPlayToEnd)
        XCTAssertNotEqual(viewModel.avCoordinator.currentURL, missingNextURL)
        XCTAssertEqual(viewModel.supportEvents.last?.kind, .programItemFileMissing)
        XCTAssertTrue(viewModel.supportEvents.last?.detail.contains("sourceKind=media") == true)
        XCTAssertEqual(viewModel.automationRuntimeNotice?.title, "节目文件不存在")
    }

    func testPlaybackEndedDoesNotAutoOpenNonVideoNextProgram() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let htmlURL = try makeTempFileURL(ext: "html")
        let pptxURL = try makeTempFileURL(ext: "pptx")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: htmlURL)
            try? FileManager.default.removeItem(at: pptxURL)
        }
        var openedPPTXCount = 0
        viewModel.pptxOpenHandler = { _ in openedPPTXCount += 1 }

        let videoItem = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let htmlItem = ProgramItem(title: "大屏页", subtitle: "HTML", sourceURL: htmlURL)
        let pptxItem = ProgramItem(title: "汇报", subtitle: "PPTX", sourceURL: pptxURL)
        viewModel.addProgramItem(videoItem)
        viewModel.addProgramItem(htmlItem)
        viewModel.addProgramItem(pptxItem)
        viewModel.autoPlayNextVideoOnEnd = true
        viewModel.switchToProgram(videoItem)

        viewModel.avCoordinator.isPlaying = false
        viewModel.avCoordinator.didPlayToEnd = true
        viewModel.avCoordinator.onPlaybackEnded?()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertEqual(openedPPTXCount, 0)
    }

    func testPlaybackEndedDoesNotAutoAdvanceToAudioProgram() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let audioURL = try makeTempFileURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: audioURL)
        }

        let firstVideo = ProgramItem(title: "片头", subtitle: "MP4", sourceURL: videoURL)
        let nextAudio = ProgramItem(title: "暖场音乐", subtitle: "MP3", sourceURL: audioURL)
        viewModel.addProgramItem(firstVideo)
        viewModel.addProgramItem(nextAudio)
        viewModel.autoPlayNextVideoOnEnd = true
        viewModel.switchToProgram(firstVideo)

        viewModel.avCoordinator.isPlaying = false
        viewModel.avCoordinator.didPlayToEnd = true
        viewModel.avCoordinator.onPlaybackEnded?()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertNotEqual(viewModel.avCoordinator.currentURL, audioURL)
    }

    func testPlaybackEndedCallbackUsesCoordinatorHookToReturnToWallpaper() throws {
        let viewModel = makeViewModel()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let wallpaperURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: wallpaperURL)
        }

        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.setActiveWallpaper(url: wallpaperURL)
        let videoItem = ProgramItem(title: "片尾视频", subtitle: "MP4", sourceURL: videoURL)

        viewModel.isBroadcasting = true
        viewModel.switchToProgram(videoItem)
        XCTAssertEqual(viewModel.currentProgramItem, videoItem)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, videoURL)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.avCoordinator.isPlaying = false
        viewModel.avCoordinator.didPlayToEnd = true
        viewModel.avCoordinator.onPlaybackEnded?()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.avCoordinator.didPlayToEnd)
        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertTrue(viewModel.isBroadcasting)
    }

    func testPlaybackEndedWhileBroadcastingDoesNotHideOutputWindow() throws {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let wallpaperURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: wallpaperURL)
        }

        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.setActiveWallpaper(url: wallpaperURL)
        let videoItem = ProgramItem(title: "片尾视频", subtitle: "MP4", sourceURL: videoURL)
        viewModel.switchToProgram(videoItem)
        viewModel.handleBroadcastToggle()

        viewModel.avCoordinator.isPlaying = false
        viewModel.avCoordinator.didPlayToEnd = true
        viewModel.avCoordinator.onPlaybackEnded?()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }

    func testRepeatedPlaybackEndedCallbacksRemainIdleAndKeepOutputWindowVisible() throws {
        let viewModel = makeViewModel()
        let outputSpy = OutputWindowControllerSpy()
        let videoURL = try makeTempFileURL(ext: "mp4")
        let wallpaperURL = try makeWallpaperURL()
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: wallpaperURL)
        }

        viewModel.outputWindowControllerFactory = { outputSpy }
        viewModel.addWallpaper(url: wallpaperURL)
        viewModel.setActiveWallpaper(url: wallpaperURL)
        let videoItem = ProgramItem(title: "片尾视频", subtitle: "MP4", sourceURL: videoURL)
        viewModel.switchToProgram(videoItem)
        viewModel.handleBroadcastToggle()

        viewModel.avCoordinator.isPlaying = false
        viewModel.avCoordinator.didPlayToEnd = true
        viewModel.avCoordinator.onPlaybackEnded?()
        viewModel.avCoordinator.onPlaybackEnded?()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.avCoordinator.didPlayToEnd)
        XCTAssertNotNil(viewModel.backgroundImage)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(outputSpy.showCount, 1)
        XCTAssertEqual(outputSpy.hideCount, 0)
    }
}
