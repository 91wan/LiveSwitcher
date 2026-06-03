import AVFoundation
import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMRuntimeFallbackParityTests: XCTestCase {
    func testFallbackPrepareSetsActiveCallbackIdentity() throws {
        let viewModel = makeViewModel()
        let url = try makeTempFileURL(ext: "mp3")
        defer { try? FileManager.default.removeItem(at: url) }
        let item = BGMItem(title: "Fallback", url: url, category: .warmUp)
        viewModel.bgmItems = [item]

        viewModel.toggleBGM(item)

        XCTAssertNotNil(viewModel.bgmFallbackPlayer.currentItem)
        XCTAssertEqual(viewModel.activeRuntimeBGMCallbackGenerationForTesting, 1)
        XCTAssertEqual(viewModel.activeRuntimeBGMCallbackItemIDForTesting, item.id)
        XCTAssertEqual(viewModel.activeRuntimeBGMCallbackURLForTesting, item.url)
    }

    func testFallbackEndDispatchesRuntimeBGMReachedEnd() throws {
        let viewModel = makeViewModel()
        let firstURL = try makeTempFileURL(ext: "mp3")
        let secondURL = try makeTempFileURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = BGMItem(title: "A", url: firstURL, category: .warmUp)
        let second = BGMItem(title: "B", url: secondURL, category: .warmUp)
        viewModel.bgmItems = [first, second]
        viewModel.bgmPlayMode = .loopAll
        viewModel.toggleBGM(first)
        let fallbackItem = try XCTUnwrap(viewModel.bgmFallbackPlayer.currentItem)

        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: fallbackItem)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "bgmReachedEnd" })
        XCTAssertEqual(viewModel.currentBGMItem?.id, second.id)
    }

    func testFallbackFailureDispatchesRuntimeBGMFailed() throws {
        let viewModel = makeViewModel()
        let url = try makeTempFileURL(ext: "mp3")
        defer { try? FileManager.default.removeItem(at: url) }
        let item = BGMItem(title: "Broken", url: url, category: .warmUp)
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)
        let fallbackItem = try XCTUnwrap(viewModel.bgmFallbackPlayer.currentItem)

        NotificationCenter.default.post(name: .AVPlayerItemFailedToPlayToEndTime, object: fallbackItem)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "bgmFailed" })
        XCTAssertFalse(viewModel.isBGMPlaying)
    }

    func testStaleFallbackEndIgnoredByGeneration() throws {
        let viewModel = makeViewModel()
        let firstURL = try makeTempFileURL(ext: "mp3")
        let secondURL = try makeTempFileURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = BGMItem(title: "A", url: firstURL, category: .warmUp)
        let second = BGMItem(title: "B", url: secondURL, category: .warmUp)
        viewModel.bgmItems = [first, second]
        viewModel.toggleBGM(first)
        let staleItem = try XCTUnwrap(viewModel.bgmFallbackPlayer.currentItem)
        viewModel.toggleBGM(second)

        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: staleItem)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(viewModel.currentBGMItem?.id, second.id)
        XCTAssertTrue(viewModel.isBGMPlaying)
    }

    func testStaleFallbackFailureIgnoredByGeneration() throws {
        let viewModel = makeViewModel()
        let firstURL = try makeTempFileURL(ext: "mp3")
        let secondURL = try makeTempFileURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = BGMItem(title: "A", url: firstURL, category: .warmUp)
        let second = BGMItem(title: "B", url: secondURL, category: .warmUp)
        viewModel.bgmItems = [first, second]
        viewModel.toggleBGM(first)
        let staleItem = try XCTUnwrap(viewModel.bgmFallbackPlayer.currentItem)
        viewModel.toggleBGM(second)

        NotificationCenter.default.post(name: .AVPlayerItemFailedToPlayToEndTime, object: staleItem)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(viewModel.currentBGMItem?.id, second.id)
        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .bgmPlaybackFailed })
    }

    func testFallbackLoopAllUsesRuntimeReducerToAdvance() throws {
        try assertFallbackEnd(playMode: .loopAll, startsAtLast: false, expectedPlaying: true)
    }

    func testFallbackSequentialUsesRuntimeReducerToStopAtLast() throws {
        try assertFallbackEnd(playMode: .sequential, startsAtLast: true, expectedPlaying: false)
    }

    private func assertFallbackEnd(
        playMode: BGMPlayMode,
        startsAtLast: Bool,
        expectedPlaying: Bool
    ) throws {
        let viewModel = makeViewModel()
        let firstURL = try makeTempFileURL(ext: "mp3")
        let secondURL = try makeTempFileURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = BGMItem(title: "A", url: firstURL, category: .warmUp)
        let second = BGMItem(title: "B", url: secondURL, category: .warmUp)
        viewModel.bgmItems = [first, second]
        viewModel.bgmPlayMode = playMode
        viewModel.toggleBGM(startsAtLast ? second : first)
        let fallbackItem = try XCTUnwrap(viewModel.bgmFallbackPlayer.currentItem)

        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: fallbackItem)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "bgmReachedEnd" })
        XCTAssertEqual(viewModel.isBGMPlaying, expectedPlaying)
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "BGMRuntimeFallbackParityTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
        viewModel.liveAudioFadeDuration = 0
        return viewModel
    }

    private func makeTempFileURL(ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try Data("not-a-decodable-audio-fixture".utf8).write(to: url)
        return url
    }
}
