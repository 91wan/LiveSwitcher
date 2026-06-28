import AVKit
import XCTest
@testable import LiveSwitcher

@MainActor
final class VideoLayerVisibilityTests: XCTestCase {
    private func makeTempURL(ext: String = "mp4") throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        FileManager.default.createFile(atPath: url.path, contents: Data("stub".utf8))
        return url
    }

    func testPausedMediaKeepsMonitorVideoLayerVisible() throws {
        let coordinator = AVPlayerCoordinator()
        let url = try makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        coordinator.load(url: url)
        coordinator.play()
        coordinator.pause()

        XCTAssertFalse(coordinator.isPlaying)
        XCTAssertEqual(coordinator.currentURL, url)
        XCTAssertTrue(coordinator.hasLoadedMedia)
        XCTAssertTrue(VideoLayerVisibilityModel.shouldShowMonitorVideoLayer(
            sourceKind: .media,
            hasLoadedMedia: coordinator.hasLoadedMedia
        ))
    }

    func testOutputVideoLayerOnlyShowsLoadedPlayingMedia() throws {
        let coordinator = AVPlayerCoordinator()
        let url = try makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        coordinator.load(url: url)

        XCTAssertTrue(coordinator.hasLoadedMedia)
        XCTAssertFalse(coordinator.isPlaying)
        XCTAssertFalse(VideoLayerVisibilityModel.shouldShowOutputVideoLayer(
            sourceKind: .media,
            hasLoadedMedia: coordinator.hasLoadedMedia,
            isPlaying: coordinator.isPlaying
        ))

        coordinator.play()

        XCTAssertTrue(VideoLayerVisibilityModel.shouldShowOutputVideoLayer(
            sourceKind: .media,
            hasLoadedMedia: coordinator.hasLoadedMedia,
            isPlaying: coordinator.isPlaying
        ))

        coordinator.pause()

        XCTAssertTrue(coordinator.hasLoadedMedia)
        XCTAssertFalse(VideoLayerVisibilityModel.shouldShowOutputVideoLayer(
            sourceKind: .media,
            hasLoadedMedia: coordinator.hasLoadedMedia,
            isPlaying: coordinator.isPlaying
        ))

        coordinator.didPlayToEnd = true

        XCTAssertFalse(VideoLayerVisibilityModel.shouldShowOutputVideoLayer(
            sourceKind: .media,
            hasLoadedMedia: coordinator.hasLoadedMedia,
            isPlaying: false
        ))
    }

    func testOutputVideoLayerStaysMountedDuringPanicPauseToAvoidWallpaperFlash() throws {
        let coordinator = AVPlayerCoordinator()
        let url = try makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        coordinator.load(url: url)
        coordinator.play()
        coordinator.pause()

        XCTAssertTrue(coordinator.hasLoadedMedia)
        XCTAssertFalse(coordinator.isPlaying)
        XCTAssertTrue(VideoLayerVisibilityModel.shouldShowOutputVideoLayer(
            sourceKind: .media,
            hasLoadedMedia: coordinator.hasLoadedMedia,
            isPlaying: coordinator.isPlaying,
            isPanicMode: true
        ))
    }

    func testStopClearsLoadedMediaAndHidesVideoLayer() throws {
        let coordinator = AVPlayerCoordinator()
        let url = try makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        coordinator.load(url: url)
        coordinator.play()
        coordinator.stop()

        XCTAssertFalse(coordinator.isPlaying)
        XCTAssertNil(coordinator.currentURL)
        XCTAssertFalse(coordinator.hasLoadedMedia)
        XCTAssertFalse(VideoLayerVisibilityModel.shouldShowMonitorVideoLayer(
            sourceKind: .media,
            hasLoadedMedia: coordinator.hasLoadedMedia
        ))
        XCTAssertFalse(VideoLayerVisibilityModel.shouldShowOutputVideoLayer(
            sourceKind: .media,
            hasLoadedMedia: coordinator.hasLoadedMedia,
            isPlaying: coordinator.isPlaying
        ))
    }

    func testLoadingNewMediaResetsPlayingStateUntilPlayIsRequested() throws {
        let coordinator = AVPlayerCoordinator()
        let firstURL = try makeTempURL()
        let secondURL = try makeTempURL()
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }

        coordinator.load(url: firstURL)
        coordinator.play()
        XCTAssertTrue(coordinator.isPlaying)

        coordinator.load(url: secondURL)

        XCTAssertEqual(coordinator.currentURL, secondURL)
        XCTAssertTrue(coordinator.hasLoadedMedia)
        XCTAssertFalse(coordinator.isPlaying)
    }

    func testStaleMediaEndNotificationCannotMarkNewLoadedMediaEnded() throws {
        let coordinator = AVPlayerCoordinator()
        let firstURL = try makeTempURL()
        let secondURL = try makeTempURL()
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        var playbackEndedCount = 0
        coordinator.onPlaybackEnded = {
            playbackEndedCount += 1
        }

        coordinator.load(url: firstURL)
        coordinator.play()
        let staleItem = try XCTUnwrap(coordinator.player.currentItem)

        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: staleItem)
        coordinator.load(url: secondURL)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(coordinator.currentURL, secondURL)
        XCTAssertFalse(coordinator.didPlayToEnd)
        XCTAssertEqual(playbackEndedCount, 0)
    }

    func testPauseThenPlayPreservesCurrentItemAndLoadedMedia() throws {
        let coordinator = AVPlayerCoordinator()
        let url = try makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        coordinator.load(url: url)
        coordinator.play()
        let loadedItem = coordinator.player.currentItem

        coordinator.pause()
        coordinator.play()

        XCTAssertTrue(coordinator.isPlaying)
        XCTAssertTrue(coordinator.hasLoadedMedia)
        XCTAssertTrue(coordinator.player.currentItem === loadedItem)
        XCTAssertEqual(coordinator.currentURL, url)
    }

    func testPlayAfterReachedEndClearsEndedStateBeforeRestarting() throws {
        let coordinator = AVPlayerCoordinator()
        let url = try makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        coordinator.load(url: url)
        coordinator.play()
        coordinator.didPlayToEnd = true
        coordinator.pause()

        coordinator.play()

        XCTAssertFalse(coordinator.didPlayToEnd)
        XCTAssertTrue(coordinator.hasLoadedMedia)
        XCTAssertEqual(coordinator.currentURL, url)
    }

    func testSeekingAfterReachedEndClearsEndedState() throws {
        let coordinator = AVPlayerCoordinator()
        let url = try makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        coordinator.load(url: url)
        coordinator.play()
        coordinator.didPlayToEnd = true

        coordinator.seek(to: 12)

        XCTAssertFalse(coordinator.didPlayToEnd)
        XCTAssertTrue(coordinator.hasLoadedMedia)
        XCTAssertEqual(coordinator.currentURL, url)
    }

    func testSeekUpdatesDisplayedProgressImmediately() throws {
        let coordinator = AVPlayerCoordinator()
        let url = try makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        coordinator.load(url: url)
        coordinator.duration = 100

        coordinator.seek(to: 25)

        XCTAssertEqual(coordinator.currentTime, 25)
        XCTAssertEqual(coordinator.progress, 0.25, accuracy: 0.001)
    }

    func testSeekToEndAfterReachedEndClearsEndedState() throws {
        let coordinator = AVPlayerCoordinator()
        let url = try makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        coordinator.load(url: url)
        coordinator.duration = 25
        coordinator.play()
        coordinator.didPlayToEnd = true

        coordinator.seekToEnd()

        XCTAssertFalse(coordinator.didPlayToEnd)
        XCTAssertTrue(coordinator.hasLoadedMedia)
        XCTAssertEqual(coordinator.currentURL, url)
    }

    func testSeekToEndTargetNeverGoesNegativeForShortMedia() {
        XCTAssertEqual(AVPlayerSeekTargetPolicy.seekToEndSeconds(duration: .nan), 0)
        XCTAssertEqual(AVPlayerSeekTargetPolicy.seekToEndSeconds(duration: .infinity), 0)
        XCTAssertEqual(AVPlayerSeekTargetPolicy.seekToEndSeconds(duration: -4), 0)
        XCTAssertEqual(AVPlayerSeekTargetPolicy.seekToEndSeconds(duration: 0.2), 0)
        XCTAssertEqual(AVPlayerSeekTargetPolicy.seekToEndSeconds(duration: 0.5), 0)
        XCTAssertEqual(AVPlayerSeekTargetPolicy.seekToEndSeconds(duration: 10), 9.5)
    }

    func testSeekToEndNoopsWhenDurationIsNotFinite() throws {
        let coordinator = AVPlayerCoordinator()
        let url = try makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        coordinator.load(url: url)
        coordinator.duration = .infinity
        coordinator.didPlayToEnd = true
        coordinator.progress = 1.0
        coordinator.currentTime = 12

        coordinator.seekToEnd()

        XCTAssertTrue(coordinator.didPlayToEnd)
        XCTAssertEqual(coordinator.progress, 1.0)
        XCTAssertEqual(coordinator.currentTime, 12)
    }

    func testManualSeekTargetIsClampedToPlayableMediaRange() {
        XCTAssertEqual(AVPlayerSeekTargetPolicy.manualSeekSeconds(seconds: -8, duration: 120), 0)
        XCTAssertEqual(AVPlayerSeekTargetPolicy.manualSeekSeconds(seconds: 32, duration: 120), 32)
        XCTAssertEqual(AVPlayerSeekTargetPolicy.manualSeekSeconds(seconds: 161, duration: 144), 144)
        XCTAssertEqual(AVPlayerSeekTargetPolicy.manualSeekSeconds(seconds: .nan, duration: 144), 0)
        XCTAssertEqual(AVPlayerSeekTargetPolicy.manualSeekSeconds(seconds: 42, duration: nil), 42)
    }

    func testRestartFromBeginningKeepsPlayingStateWhileSeekIsPending() throws {
        let coordinator = AVPlayerCoordinator()
        let url = try makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        coordinator.load(url: url)
        coordinator.play()
        XCTAssertTrue(coordinator.isPlaying)

        coordinator.restartFromBeginning()

        XCTAssertTrue(coordinator.isPlaying)
        XCTAssertTrue(coordinator.hasLoadedMedia)
        XCTAssertEqual(coordinator.currentURL, url)
    }

    func testStaleRestartSeekCompletionCannotStartNewLoadedMedia() throws {
        let coordinator = AVPlayerCoordinator()
        let firstURL = try makeTempURL()
        let secondURL = try makeTempURL()
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        var restartReadyCount = 0

        coordinator.load(url: firstURL)
        coordinator.play()
        coordinator.restartFromBeginning {
            restartReadyCount += 1
        }
        coordinator.load(url: secondURL)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(coordinator.currentURL, secondURL)
        XCTAssertFalse(coordinator.isPlaying)
        XCTAssertEqual(restartReadyCount, 0)
    }

    func testStaleSeekToEndCompletionCannotMarkNewLoadedMediaComplete() throws {
        let coordinator = AVPlayerCoordinator()
        let firstURL = try makeTempURL()
        let secondURL = try makeTempURL()
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }

        coordinator.load(url: firstURL)
        coordinator.duration = 25
        coordinator.seekToEnd()
        coordinator.load(url: secondURL)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(coordinator.currentURL, secondURL)
        XCTAssertEqual(coordinator.progress, 0)
        XCTAssertEqual(coordinator.currentTime, 0)
    }

    func testPlayWithoutLoadedMediaDoesNotReportPlaying() {
        let coordinator = AVPlayerCoordinator()

        coordinator.play()

        XCTAssertFalse(coordinator.isPlaying)
        XCTAssertFalse(coordinator.hasLoadedMedia)
        XCTAssertNil(coordinator.currentURL)
    }

    func testPlayWithMissingCurrentItemDoesNotImplicitlyReloadByDefault() throws {
        let coordinator = AVPlayerCoordinator()
        let url = try makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        coordinator.load(url: url)
        coordinator.currentTime = 42
        coordinator.progress = 0.42
        coordinator.player.replaceCurrentItem(with: nil)

        coordinator.play()

        XCTAssertFalse(coordinator.isPlaying)
        XCTAssertNil(coordinator.player.currentItem)
        XCTAssertEqual(coordinator.currentURL, url)
        XCTAssertEqual(coordinator.currentTime, 42)
        XCTAssertEqual(coordinator.progress, 0.42)
    }

    func testExplicitReloadCanRebuildMissingCurrentItem() throws {
        let coordinator = AVPlayerCoordinator()
        let url = try makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        coordinator.load(url: url)
        coordinator.player.replaceCurrentItem(with: nil)

        coordinator.play(reloadIfNeeded: true)

        XCTAssertTrue(coordinator.isPlaying)
        XCTAssertNotNil(coordinator.player.currentItem)
        XCTAssertEqual(coordinator.currentURL, url)
        XCTAssertTrue(coordinator.hasLoadedMedia)
    }

    func testNonMediaSourceHidesLoadedVideoLayer() throws {
        let coordinator = AVPlayerCoordinator()
        let url = try makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        coordinator.load(url: url)

        XCTAssertTrue(coordinator.hasLoadedMedia)
        XCTAssertFalse(VideoLayerVisibilityModel.shouldShowMonitorVideoLayer(sourceKind: .html, hasLoadedMedia: coordinator.hasLoadedMedia))
        XCTAssertFalse(VideoLayerVisibilityModel.shouldShowMonitorVideoLayer(sourceKind: .pptx, hasLoadedMedia: coordinator.hasLoadedMedia))
        XCTAssertFalse(VideoLayerVisibilityModel.shouldShowMonitorVideoLayer(sourceKind: .keynote, hasLoadedMedia: coordinator.hasLoadedMedia))
        XCTAssertFalse(VideoLayerVisibilityModel.shouldShowOutputVideoLayer(sourceKind: .html, hasLoadedMedia: coordinator.hasLoadedMedia, isPlaying: true))
        XCTAssertFalse(VideoLayerVisibilityModel.shouldShowOutputVideoLayer(sourceKind: .pptx, hasLoadedMedia: coordinator.hasLoadedMedia, isPlaying: true))
        XCTAssertFalse(VideoLayerVisibilityModel.shouldShowOutputVideoLayer(sourceKind: .keynote, hasLoadedMedia: coordinator.hasLoadedMedia, isPlaying: true))
    }

    func testVideoLayerVisibilityModelSeparatesMonitorAndOutputPolicies() {
        let pausedMedia = VideoLayerVisibilityModel.make(
            sourceKind: .media,
            hasLoadedMedia: true,
            isPlaying: false
        )
        let playingMedia = VideoLayerVisibilityModel.make(
            sourceKind: .media,
            hasLoadedMedia: true,
            isPlaying: true
        )

        XCTAssertTrue(pausedMedia.shouldShowMonitorVideoLayer)
        XCTAssertFalse(pausedMedia.shouldShowOutputVideoLayer)
        XCTAssertTrue(playingMedia.shouldShowMonitorVideoLayer)
        XCTAssertTrue(playingMedia.shouldShowOutputVideoLayer)
    }

    func testVideoLayerVisibilityModelUsesCurrentProgramSourceKindNotLoadedURLAssumptions() {
        let loadedHTML = VideoLayerVisibilityModel.make(
            sourceKind: .html,
            hasLoadedMedia: true,
            isPlaying: true
        )
        let loadedDeck = VideoLayerVisibilityModel.make(
            sourceKind: .pptx,
            hasLoadedMedia: true,
            isPlaying: true
        )
        let loadedMedia = VideoLayerVisibilityModel.make(
            sourceKind: .media,
            hasLoadedMedia: true,
            isPlaying: true
        )

        XCTAssertFalse(loadedHTML.shouldShowMonitorVideoLayer)
        XCTAssertFalse(loadedHTML.shouldShowOutputVideoLayer)
        XCTAssertFalse(loadedDeck.shouldShowMonitorVideoLayer)
        XCTAssertFalse(loadedDeck.shouldShowOutputVideoLayer)
        XCTAssertTrue(loadedMedia.shouldShowMonitorVideoLayer)
        XCTAssertTrue(loadedMedia.shouldShowOutputVideoLayer)
    }

    func testOutputVisibilityCoordinatorAppliesLatestSourcePlayingAndPanicState() {
        let coordinator = OutputVideoPlayerView.VisibilityCoordinator()
        let view = AVPlayerView()

        coordinator.update(
            sourceKind: .media,
            isPanicMode: false,
            hasLoadedMedia: true,
            isPlaying: false,
            view: view
        )
        XCTAssertTrue(view.isHidden)

        coordinator.update(
            sourceKind: .media,
            isPanicMode: true,
            hasLoadedMedia: true,
            isPlaying: false,
            view: view
        )
        XCTAssertFalse(view.isHidden)

        coordinator.update(
            sourceKind: .html,
            isPanicMode: true,
            hasLoadedMedia: true,
            isPlaying: true,
            view: view
        )
        XCTAssertTrue(view.isHidden)
    }

    func testMonitorPolicyKeepsPausedMediaVisibleWithoutOutputPlaybackRequirement() {
        XCTAssertTrue(VideoLayerVisibilityModel.shouldShowMonitorVideoLayer(sourceKind: .media, hasLoadedMedia: true))
        XCTAssertFalse(VideoLayerVisibilityModel.shouldShowMonitorVideoLayer(sourceKind: .media, hasLoadedMedia: false))
        XCTAssertFalse(VideoLayerVisibilityModel.shouldShowMonitorVideoLayer(sourceKind: .html, hasLoadedMedia: true))
        XCTAssertFalse(VideoLayerVisibilityModel.shouldShowMonitorVideoLayer(sourceKind: nil, hasLoadedMedia: true))
    }
}
