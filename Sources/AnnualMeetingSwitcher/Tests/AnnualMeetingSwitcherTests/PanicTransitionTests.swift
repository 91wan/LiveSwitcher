import XCTest
import AppKit
@testable import LiveSwitcher

@MainActor
final class PanicTransitionTests: XCTestCase {
    private func makeViewModel() -> SwitcherViewModel {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.externalScreenProvider = { NSScreen.main ?? NSScreen.screens.first }
        viewModel.keynotePresentationHandler = { _ in }
        viewModel.pptxOpenHandler = { _ in }
        viewModel.activeDeckPresentationHandler = {}
        viewModel.invalidDeckHandler = { _ in }
        viewModel.deckStopHandler = {}
        return viewModel
    }

    private func makeTempURL(ext: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        FileManager.default.createFile(atPath: url.path, contents: Data("stub".utf8))
        return url
    }

    func testPanicUsesFadedAudioRouting() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 1.4
        let videoURL = try makeTempURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        viewModel.togglePanicMode()

        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .panicChanged)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.mediaFadeDuration, 1.4)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.bgmFadeDuration, 1.4)
        XCTAssertEqual(viewModel.effectiveMediaOutputVolume(), 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.effectiveBGMOutputVolume(), 0, accuracy: 0.0001)
    }

    func testPanicPausesBGMAndRestoresOnlyIfItWasPlaying() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let bgmURL = try makeTempURL(ext: "mp3")
        defer { try? FileManager.default.removeItem(at: bgmURL) }
        let item = BGMItem(title: "Walk-in", url: bgmURL, category: .warmUp)

        viewModel.toggleBGM(item)
        XCTAssertTrue(viewModel.isBGMPlaying)

        viewModel.togglePanicMode()
        XCTAssertFalse(viewModel.isBGMPlaying)

        viewModel.togglePanicMode()
        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertEqual(viewModel.currentBGMItem?.id, item.id)
    }

    func testPanicDoesNotResumeBGMIfTrackChangedDuringPanic() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let firstURL = try makeTempURL(ext: "mp3")
        let secondURL = try makeTempURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = BGMItem(title: "First", url: firstURL, category: .warmUp)
        let second = BGMItem(title: "Second", url: secondURL, category: .warmUp)

        viewModel.toggleBGM(first)
        viewModel.togglePanicMode()
        viewModel.currentBGMItem = second

        viewModel.togglePanicMode()

        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertEqual(viewModel.currentBGMItem?.id, second.id)
    }

    func testPanicPausesMediaImmediatelyButWaitsForAudioFadeBeforePausingBGM() async throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0.5
        let videoURL = try makeTempURL(ext: "mp4")
        let bgmURL = try makeTempURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: bgmURL)
        }
        let bgm = BGMItem(title: "Walk-in", url: bgmURL, category: .warmUp)

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        viewModel.currentBGMItem = bgm
        viewModel.isBGMPlaying = true

        viewModel.togglePanicMode()
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBGMPlaying)

        try await Task.sleep(nanoseconds: 350_000_000)

        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
        XCTAssertFalse(viewModel.isBGMPlaying)
    }

    func testSwitchingToMediaDuringPanicLoadsButDoesNotPlay() async throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0.12
        let firstURL = try makeTempURL(ext: "mp4")
        let secondURL = try makeTempURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = ProgramItem(title: "First", subtitle: "MP4", sourceURL: firstURL)
        let second = ProgramItem(title: "Second", subtitle: "MP4", sourceURL: secondURL)

        viewModel.switchToProgram(first)
        viewModel.togglePanicMode()
        viewModel.switchToProgram(second)

        try await Task.sleep(nanoseconds: 180_000_000)

        XCTAssertEqual(viewModel.currentProgramItem?.id, second.id)
        XCTAssertTrue(viewModel.avCoordinator.hasLoadedMedia)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }

    func testDelayedPanicPauseDoesNotPauseNewBGMSelectedDuringPanic() async throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0.12
        let firstURL = try makeTempURL(ext: "mp3")
        let secondURL = try makeTempURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = BGMItem(title: "First", url: firstURL, category: .warmUp)
        let second = BGMItem(title: "Second", url: secondURL, category: .warmUp)

        viewModel.currentBGMItem = first
        viewModel.isBGMPlaying = true
        viewModel.togglePanicMode()
        viewModel.currentBGMItem = second
        viewModel.isBGMPlaying = true

        try await Task.sleep(nanoseconds: 180_000_000)

        XCTAssertEqual(viewModel.currentBGMItem?.id, second.id)
        XCTAssertTrue(viewModel.isBGMPlaying)
    }

    func testFadeToBlackDoesNotChangeMediaOrBGMPlayback() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let videoURL = try makeTempURL(ext: "mp4")
        let bgmURL = try makeTempURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: videoURL)
            try? FileManager.default.removeItem(at: bgmURL)
        }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        viewModel.toggleBGM(BGMItem(title: "Walk-in", url: bgmURL, category: .warmUp))
        viewModel.resetLastAudioRoutingTransitionForTesting()

        viewModel.toggleFadeToBlack()

        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertNil(viewModel.lastAudioRoutingTransition)
    }

    func testRestartCurrentMediaDuringPanicSeeksButDoesNotPlay() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let videoURL = try makeTempURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
        viewModel.togglePanicMode()

        viewModel.restartCurrentMediaFromBeginning()

        XCTAssertTrue(viewModel.isPanicMode)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }

    func testToggleMainVideoPlaybackDuringPanicDoesNotStartMedia() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let videoURL = try makeTempURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        viewModel.togglePanicMode()

        viewModel.toggleMainVideoPlayback()

        XCTAssertTrue(viewModel.isPanicMode)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }

    func testRuntimeMediaPauseDuringPanicDoesNotClearResumeSnapshot() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 1
        let videoURL = try makeTempURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)

        viewModel.togglePanicMode()
        XCTAssertTrue(viewModel.isPanicMode)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)

        viewModel.toggleMainVideoPlayback()
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)

        viewModel.togglePanicMode()

        XCTAssertFalse(viewModel.isPanicMode)
        XCTAssertTrue(viewModel.avCoordinator.isPlaying)
    }

    func testPlaybackEndedDuringPanicDoesNotAutoAdvanceQueue() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let firstURL = try makeTempURL(ext: "mp4")
        let secondURL = try makeTempURL(ext: "mp4")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: firstURL)
        let second = ProgramItem(title: "Awards", subtitle: "MP4", sourceURL: secondURL)
        viewModel.programItems = [first, second]
        viewModel.autoPlayNextVideoOnEnd = true
        viewModel.switchToProgram(first)
        viewModel.togglePanicMode()

        viewModel.avCoordinator.didPlayToEnd = true
        viewModel.handlePlaybackEnded()

        XCTAssertTrue(viewModel.isPanicMode)
        XCTAssertEqual(viewModel.currentProgramItem?.id, first.id)
        XCTAssertEqual(viewModel.avCoordinator.currentURL, firstURL)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }

    func testPanicDoesNotResumeMediaIfPlaybackEndedDuringPanic() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let videoURL = try makeTempURL(ext: "mp4")
        defer { try? FileManager.default.removeItem(at: videoURL) }

        viewModel.switchToProgram(ProgramItem(title: "Opening", subtitle: "MP4", sourceURL: videoURL))
        viewModel.togglePanicMode()

        viewModel.avCoordinator.didPlayToEnd = true
        viewModel.handlePlaybackEnded()
        viewModel.togglePanicMode()

        XCTAssertFalse(viewModel.isPanicMode)
        XCTAssertFalse(viewModel.avCoordinator.isPlaying)
    }

    func testPanicDoesNotResumeBGMIfTrackFinishedDuringPanic() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let bgmURL = try makeTempURL(ext: "mp3")
        defer { try? FileManager.default.removeItem(at: bgmURL) }
        let item = BGMItem(title: "Walk-in", url: bgmURL, category: .warmUp)

        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)
        viewModel.togglePanicMode()

        viewModel.bgmDidFinish()
        viewModel.togglePanicMode()

        XCTAssertFalse(viewModel.isPanicMode)
        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertEqual(viewModel.currentBGMItem?.id, item.id)
    }

    func testSelectingBGMDuringPanicCuesButDoesNotPlay() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let bgmURL = try makeTempURL(ext: "mp3")
        defer { try? FileManager.default.removeItem(at: bgmURL) }
        let item = BGMItem(title: "Hold Music", url: bgmURL, category: .warmUp)

        viewModel.togglePanicMode()
        viewModel.toggleBGM(item)

        XCTAssertTrue(viewModel.isPanicMode)
        XCTAssertEqual(viewModel.currentBGMItem?.id, item.id)
        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertNil(viewModel.bgmFallbackPlayer.currentItem)
    }

    func testResumingSelectedBGMDuringPanicDoesNotStartPlayback() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let bgmURL = try makeTempURL(ext: "mp3")
        defer { try? FileManager.default.removeItem(at: bgmURL) }
        let item = BGMItem(title: "Hold Music", url: bgmURL, category: .warmUp)
        viewModel.currentBGMItem = item
        viewModel.isBGMPlaying = false

        viewModel.togglePanicMode()
        viewModel.toggleBGM(item)

        XCTAssertTrue(viewModel.isPanicMode)
        XCTAssertEqual(viewModel.currentBGMItem?.id, item.id)
        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertNil(viewModel.bgmFallbackPlayer.currentItem)
    }

    func testTogglingSelectedBGMDuringPanicForcesStoppedState() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let bgmURL = try makeTempURL(ext: "mp3")
        defer { try? FileManager.default.removeItem(at: bgmURL) }
        let item = BGMItem(title: "Hold Music", url: bgmURL, category: .warmUp)
        viewModel.currentBGMItem = item
        viewModel.isBGMPlaying = true

        viewModel.togglePanicMode()
        viewModel.isBGMPlaying = true
        viewModel.toggleBGM(item)

        XCTAssertTrue(viewModel.isPanicMode)
        XCTAssertEqual(viewModel.currentBGMItem?.id, item.id)
        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertNil(viewModel.bgmFallbackPlayer.currentItem)
    }

    func testTogglingSameBGMDuringPanicPreventsAutomaticResume() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let bgmURL = try makeTempURL(ext: "mp3")
        defer { try? FileManager.default.removeItem(at: bgmURL) }
        let item = BGMItem(title: "Hold Music", url: bgmURL, category: .warmUp)
        viewModel.currentBGMItem = item
        viewModel.isBGMPlaying = true

        viewModel.togglePanicMode()
        viewModel.isBGMPlaying = true
        viewModel.toggleBGM(item)
        viewModel.togglePanicMode()

        XCTAssertFalse(viewModel.isPanicMode)
        XCTAssertEqual(viewModel.currentBGMItem?.id, item.id)
        XCTAssertFalse(viewModel.isBGMPlaying)
    }

    func testBGMFinishDuringPanicDoesNotAdvanceToNextTrack() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let firstURL = try makeTempURL(ext: "mp3")
        let secondURL = try makeTempURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = BGMItem(title: "First", url: firstURL, category: .warmUp)
        let second = BGMItem(title: "Second", url: secondURL, category: .warmUp)
        viewModel.bgmItems = [first, second]
        viewModel.toggleBGM(first)

        viewModel.togglePanicMode()
        viewModel.bgmDidFinish()

        XCTAssertTrue(viewModel.isPanicMode)
        XCTAssertEqual(viewModel.currentBGMItem?.id, first.id)
        XCTAssertFalse(viewModel.isBGMPlaying)
    }
}
