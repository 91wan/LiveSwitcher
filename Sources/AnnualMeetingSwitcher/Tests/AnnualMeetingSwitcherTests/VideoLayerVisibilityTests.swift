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

    func testOutputVideoPlayerVisibilitySubscribesToLoadedMediaAndPlayingState() throws {
        let source = try sourceText("Output/OutputWindowController.swift")

        XCTAssertFalse(source.contains("isHidden = !coordinator.isPlaying"))
        XCTAssertFalse(source.contains("view?.isHidden = !isPlaying"))
        XCTAssertTrue(source.contains("avCoordinator.$hasLoadedMedia"))
        XCTAssertTrue(source.contains("avCoordinator.$isPlaying"))
        XCTAssertTrue(source.contains("isPlaying: coordinator.isPlaying"))
        XCTAssertTrue(source.contains("isPlaying: isPlaying"))
        XCTAssertTrue(source.contains("VideoLayerVisibilityModel"))
        XCTAssertTrue(source.contains("VideoLayerVisibilityModel.shouldShowOutputVideoLayer"))
        XCTAssertFalse(source.contains("VideoLayerVisibilityModel.shouldShowVideoLayer"))
    }

    func testOutputVideoPlayerVisibilityUsesCurrentProgramSourceKindNotLoadedURL() throws {
        let source = try sourceText("Output/OutputWindowController.swift")

        XCTAssertTrue(source.contains("sourceKind: viewModel.currentProgramItem?.sourceKind"))
        XCTAssertFalse(source.contains("sourceKind: coordinator.currentURL.map { _ in .media }"))
        XCTAssertFalse(source.contains("sourceKind: avCoordinator.currentURL.map { _ in .media }"))
    }

    func testOutputVideoPlayerReadsPanicStateWhenVisibilityUpdates() throws {
        let source = try sourceText("Output/OutputWindowController.swift")

        XCTAssertTrue(source.contains("isPanicModeProvider"))
        XCTAssertTrue(source.contains("isPanicMode: isPanicModeProvider()"))
        XCTAssertFalse(source.contains("private var isPanicMode = false"))
    }

    func testProgramMonitorDoesNotMountVideoOnlyWhilePlaying() throws {
        let source = try sourceText("Views/ProgramMonitor/ProgramMonitorMediaLayer.swift")

        XCTAssertFalse(source.contains("if viewModel.avCoordinator.isPlaying {\n            VideoPlayerView"))
        XCTAssertTrue(source.contains("VideoLayerVisibilityModel.shouldShowMonitorVideoLayer"))
        XCTAssertFalse(source.contains("VideoLayerVisibilityModel.shouldShowOutputVideoLayer"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try LiveSwitcherTests.sourceText(relativePath, filePath: #filePath)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
