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
