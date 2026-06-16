import AVFoundation
import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMFallbackPlaybackTests: XCTestCase {
    func testFallbackPlayerEndNotificationAdvancesToNextTrack() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let firstURL = try makeTempFileURL(ext: "mp3")
        let secondURL = try makeTempFileURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = BGMItem(title: "Fallback A", url: firstURL, category: .warmUp)
        let second = BGMItem(title: "Fallback B", url: secondURL, category: .warmUp)
        viewModel.bgmItems = [first, second]

        viewModel.toggleBGM(first)
        let fallbackItem = try XCTUnwrap(viewModel.bgmFallbackPlayer.currentItem)

        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: fallbackItem)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(viewModel.currentBGMItem?.id, second.id)
        XCTAssertTrue(viewModel.isBGMPlaying)
    }

    func testFallbackLoopOneRepeatsSameTrackOnEndNotification() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.dispatchRuntimeFacadeAction(.operatorSelectedBGMPlayMode(.loopOne))
        let url = try makeTempFileURL(ext: "mp3")
        defer { try? FileManager.default.removeItem(at: url) }
        let item = BGMItem(title: "Fallback Loop", url: url, category: .warmUp)
        viewModel.bgmItems = [item]

        viewModel.toggleBGM(item)
        let firstFallbackItem = try XCTUnwrap(viewModel.bgmFallbackPlayer.currentItem)

        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: firstFallbackItem)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(viewModel.currentBGMItem?.id, item.id)
        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertNotNil(viewModel.bgmFallbackPlayer.currentItem)
        XCTAssertFalse(viewModel.bgmFallbackPlayer.currentItem === firstFallbackItem)
    }

    func testFallbackSequentialStopsAtLastTrackOnEndNotification() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.dispatchRuntimeFacadeAction(.operatorSelectedBGMPlayMode(.sequential))
        let firstURL = try makeTempFileURL(ext: "mp3")
        let secondURL = try makeTempFileURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = BGMItem(title: "Fallback A", url: firstURL, category: .warmUp)
        let second = BGMItem(title: "Fallback B", url: secondURL, category: .warmUp)
        viewModel.bgmItems = [first, second]

        viewModel.toggleBGM(second)
        let fallbackItem = try XCTUnwrap(viewModel.bgmFallbackPlayer.currentItem)

        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: fallbackItem)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(viewModel.currentBGMItem?.id, second.id)
        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertNil(viewModel.bgmFallbackPlayer.currentItem)
        XCTAssertEqual(viewModel.bgmProgress, 0)
    }

    func testFallbackLoopAllWrapsLastTrackToFirstOnEndNotification() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.dispatchRuntimeFacadeAction(.operatorSelectedBGMPlayMode(.loopAll))
        let firstURL = try makeTempFileURL(ext: "mp3")
        let secondURL = try makeTempFileURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = BGMItem(title: "Fallback A", url: firstURL, category: .warmUp)
        let second = BGMItem(title: "Fallback B", url: secondURL, category: .warmUp)
        viewModel.bgmItems = [first, second]

        viewModel.toggleBGM(second)
        let fallbackItem = try XCTUnwrap(viewModel.bgmFallbackPlayer.currentItem)

        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: fallbackItem)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(viewModel.currentBGMItem?.id, first.id)
        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertNotNil(viewModel.bgmFallbackPlayer.currentItem)
    }

    func testSwitchingFallbackBGMKeepsOldItemLoadedForFadeOut() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0.2
        let firstURL = try makeTempFileURL(ext: "mp3")
        let secondURL = try makeTempFileURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = BGMItem(title: "Fallback A", url: firstURL, category: .warmUp)
        let second = BGMItem(title: "Fallback B", url: secondURL, category: .warmUp)
        viewModel.bgmItems = [first, second]

        viewModel.toggleBGM(first)
        let retiringPlayer = viewModel.bgmFallbackPlayer
        let retiringItem = try XCTUnwrap(retiringPlayer.currentItem)
        retiringPlayer.volume = 0.6

        viewModel.toggleBGM(second)

        XCTAssertFalse(viewModel.bgmFallbackPlayer === retiringPlayer)
        XCTAssertTrue(retiringPlayer.currentItem === retiringItem)
        XCTAssertNotNil(viewModel.bgmFallbackPlayer.currentItem)
        XCTAssertEqual(viewModel.currentBGMItem?.id, second.id)
        XCTAssertTrue(viewModel.isBGMPlaying)
    }

    func testStaleFallbackEndNotificationCannotAdvanceNewCurrentTrack() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let firstURL = try makeTempFileURL(ext: "mp3")
        let secondURL = try makeTempFileURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }
        let first = BGMItem(title: "Fallback A", url: firstURL, category: .warmUp)
        let second = BGMItem(title: "Fallback B", url: secondURL, category: .warmUp)
        viewModel.bgmItems = [first, second]

        viewModel.toggleBGM(first)
        let staleItem = try XCTUnwrap(viewModel.bgmFallbackPlayer.currentItem)

        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: staleItem)
        viewModel.toggleBGM(second)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(viewModel.currentBGMItem?.id, second.id)
        XCTAssertTrue(viewModel.isBGMPlaying)
    }

    func testRapidFallbackSwitchesIgnoreStaleEndAndFailureNotifications() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let firstURL = try makeTempFileURL(ext: "mp3")
        let secondURL = try makeTempFileURL(ext: "mp3")
        let thirdURL = try makeTempFileURL(ext: "mp3")
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
            try? FileManager.default.removeItem(at: thirdURL)
        }
        let first = BGMItem(title: "Fallback A", url: firstURL, category: .warmUp)
        let second = BGMItem(title: "Fallback B", url: secondURL, category: .warmUp)
        let third = BGMItem(title: "Fallback C", url: thirdURL, category: .warmUp)
        viewModel.bgmItems = [first, second, third]

        viewModel.toggleBGM(first)
        let staleFirstItem = try XCTUnwrap(viewModel.bgmFallbackPlayer.currentItem)
        viewModel.toggleBGM(second)
        let staleSecondItem = try XCTUnwrap(viewModel.bgmFallbackPlayer.currentItem)
        viewModel.toggleBGM(third)

        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: staleFirstItem)
        NotificationCenter.default.post(name: .AVPlayerItemFailedToPlayToEndTime, object: staleSecondItem)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(viewModel.currentBGMItem?.id, third.id)
        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertNotNil(viewModel.bgmFallbackPlayer.currentItem)
        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .bgmPlaybackFailed })
    }

    func testFallbackPlayerFailureNotificationStopsSafely() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let url = try makeTempFileURL(ext: "mp3")
        defer { try? FileManager.default.removeItem(at: url) }
        let item = BGMItem(title: "Broken Fallback", url: url, category: .warmUp)
        viewModel.bgmItems = [item]

        viewModel.toggleBGM(item)
        let fallbackItem = try XCTUnwrap(viewModel.bgmFallbackPlayer.currentItem)

        NotificationCenter.default.post(name: .AVPlayerItemFailedToPlayToEndTime, object: fallbackItem)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(viewModel.currentBGMItem?.id, item.id)
        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertNil(viewModel.bgmFallbackPlayer.currentItem)
        XCTAssertEqual(viewModel.bgmProgress, 0)
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .bgmPlaybackFailed })
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "BGMFallbackPlaybackTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
    }

    private func makeTempFileURL(ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try Data("not-a-decodable-audio-fixture".utf8).write(to: url)
        return url
    }
}
