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

    func testPausedMediaKeepsVideoLayerVisible() throws {
        let coordinator = AVPlayerCoordinator()
        let url = try makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        coordinator.load(url: url)
        coordinator.play()
        coordinator.pause()

        XCTAssertFalse(coordinator.isPlaying)
        XCTAssertEqual(coordinator.currentURL, url)
        XCTAssertTrue(coordinator.hasLoadedMedia)
        XCTAssertTrue(VideoLayerVisibilityModel.shouldShowVideoLayer(sourceKind: .media, hasLoadedMedia: coordinator.hasLoadedMedia))
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
        XCTAssertFalse(VideoLayerVisibilityModel.shouldShowVideoLayer(sourceKind: .media, hasLoadedMedia: coordinator.hasLoadedMedia))
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

    func testNonMediaSourceHidesLoadedVideoLayer() throws {
        let coordinator = AVPlayerCoordinator()
        let url = try makeTempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        coordinator.load(url: url)

        XCTAssertTrue(coordinator.hasLoadedMedia)
        XCTAssertFalse(VideoLayerVisibilityModel.shouldShowVideoLayer(sourceKind: .html, hasLoadedMedia: coordinator.hasLoadedMedia))
        XCTAssertFalse(VideoLayerVisibilityModel.shouldShowVideoLayer(sourceKind: .pptx, hasLoadedMedia: coordinator.hasLoadedMedia))
        XCTAssertFalse(VideoLayerVisibilityModel.shouldShowVideoLayer(sourceKind: .keynote, hasLoadedMedia: coordinator.hasLoadedMedia))
    }

    func testOutputVideoPlayerDoesNotHideByPlayingState() throws {
        let source = try sourceText("Output/OutputWindowController.swift")

        XCTAssertFalse(source.contains("isHidden = !coordinator.isPlaying"))
        XCTAssertFalse(source.contains("view?.isHidden = !isPlaying"))
        XCTAssertFalse(source.contains("avCoordinator.$isPlaying"))
        XCTAssertTrue(source.contains("VideoLayerVisibilityModel"))
    }

    func testOutputVideoPlayerVisibilityUsesCurrentProgramSourceKindNotLoadedURL() throws {
        let source = try sourceText("Output/OutputWindowController.swift")

        XCTAssertTrue(source.contains("sourceKind: viewModel.currentProgramItem?.sourceKind"))
        XCTAssertFalse(source.contains("sourceKind: coordinator.currentURL.map { _ in .media }"))
        XCTAssertFalse(source.contains("sourceKind: avCoordinator.currentURL.map { _ in .media }"))
    }

    func testProgramMonitorDoesNotMountVideoOnlyWhilePlaying() throws {
        let source = try sourceText("Views/ProgramMonitorView.swift")

        XCTAssertFalse(source.contains("if viewModel.avCoordinator.isPlaying {\n            VideoPlayerView"))
        XCTAssertTrue(source.contains("VideoLayerVisibilityModel.shouldShowVideoLayer"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
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
