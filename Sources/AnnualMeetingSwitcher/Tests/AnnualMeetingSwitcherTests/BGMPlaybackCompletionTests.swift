import AVFoundation
import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMPlaybackCompletionTests: XCTestCase {
    func testLoopAllSingleTrackRestartsInsteadOfStopping() throws {
        let (directory, audioURL) = try makeAudioFixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let item = BGMItem(title: "Solo", url: audioURL, category: .warmUp)
        let viewModel = makeViewModel()
        viewModel.bgmItems = [item]
        viewModel.currentBGMItem = item
        viewModel.isBGMPlaying = true
        viewModel.bgmPlayMode = .loopAll

        viewModel.bgmDidFinish()

        XCTAssertEqual(viewModel.currentBGMItem?.id, item.id)
        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertNotNil(viewModel.bgmAudioPlayer)
        XCTAssertEqual(viewModel.bgmAudioPlayer?.currentTime ?? -1, 0, accuracy: 0.1)
    }

    func testSequentialFinishedCurrentTrackCanBePlayedAgain() throws {
        let (directory, audioURL) = try makeAudioFixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let item = BGMItem(title: "Solo", url: audioURL, category: .warmUp)
        let viewModel = makeViewModel()
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)
        XCTAssertTrue(viewModel.isBGMPlaying)
        viewModel.bgmPlayMode = .sequential

        viewModel.bgmDidFinish()
        XCTAssertEqual(viewModel.currentBGMItem?.id, item.id)
        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertNil(viewModel.bgmAudioPlayer)

        viewModel.toggleBGM(item)

        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertNotNil(viewModel.bgmAudioPlayer)
        XCTAssertEqual(viewModel.bgmAudioPlayer?.currentTime ?? -1, 0, accuracy: 0.1)
    }

    func testSequentialFinishedFallbackTrackClearsFallbackItemBeforeReplay() throws {
        let (directory, audioURL) = try makeFallbackAudioFixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let item = BGMItem(title: "Fallback", url: audioURL, category: .warmUp)
        let viewModel = makeViewModel()
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)
        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertNil(viewModel.bgmAudioPlayer)
        XCTAssertNotNil(viewModel.bgmFallbackPlayer.currentItem)
        viewModel.bgmPlayMode = .sequential

        viewModel.bgmDidFinish()

        XCTAssertEqual(viewModel.currentBGMItem?.id, item.id)
        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertNil(viewModel.bgmAudioPlayer)
        XCTAssertNil(viewModel.bgmFallbackPlayer.currentItem)

        viewModel.toggleBGM(item)

        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertNotNil(viewModel.bgmFallbackPlayer.currentItem)
    }

    func testStaleRemovedAudioPlayerFinishCannotStopNewCurrentTrack() async throws {
        let (directory, firstURL) = try makeAudioFixture(named: "first.wav")
        let secondURL = directory.appendingPathComponent("second.wav")
        try writeSineWaveFixture(to: secondURL)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = BGMItem(title: "First", url: firstURL, category: .warmUp)
        let second = BGMItem(title: "Second", url: secondURL, category: .warmUp)
        let viewModel = makeViewModel()
        viewModel.bgmItems = [first, second]
        viewModel.bgmPlayMode = .sequential
        viewModel.liveAudioFadeDuration = 1.0

        viewModel.toggleBGM(first)
        let stalePlayer = try XCTUnwrap(viewModel.bgmAudioPlayer)
        viewModel.removeBGMItem(first)
        viewModel.toggleBGM(second)
        XCTAssertEqual(viewModel.currentBGMItem?.id, second.id)
        XCTAssertTrue(viewModel.isBGMPlaying)

        viewModel.bgmDelegate.audioPlayerDidFinishPlaying(stalePlayer, successfully: true)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.currentBGMItem?.id, second.id)
        XCTAssertTrue(viewModel.isBGMPlaying)
    }

    func testStaleRemovedAudioPlayerFailureCannotStopNewCurrentTrack() async throws {
        let (directory, firstURL) = try makeAudioFixture(named: "first.wav")
        let secondURL = directory.appendingPathComponent("second.wav")
        try writeSineWaveFixture(to: secondURL)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = BGMItem(title: "First", url: firstURL, category: .warmUp)
        let second = BGMItem(title: "Second", url: secondURL, category: .warmUp)
        let viewModel = makeViewModel()
        viewModel.bgmItems = [first, second]
        viewModel.bgmPlayMode = .sequential
        viewModel.liveAudioFadeDuration = 1.0

        viewModel.toggleBGM(first)
        let stalePlayer = try XCTUnwrap(viewModel.bgmAudioPlayer)
        viewModel.removeBGMItem(first)
        viewModel.toggleBGM(second)
        XCTAssertEqual(viewModel.currentBGMItem?.id, second.id)
        XCTAssertTrue(viewModel.isBGMPlaying)

        viewModel.bgmDelegate.audioPlayerDidFinishPlaying(stalePlayer, successfully: false)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.currentBGMItem?.id, second.id)
        XCTAssertTrue(viewModel.isBGMPlaying)
    }

    func testBGMPlayModePersistsAcrossViewModelInstances() {
        let suiteName = "LiveSwitcherBGMPlayModeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
        first.bgmPlayMode = .loopOne

        let second = SwitcherViewModel(
            loadPersistedData: true,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )

        XCTAssertEqual(second.bgmPlayMode, .loopOne)
    }

    private func makeViewModel() -> SwitcherViewModel {
        SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: .standard
        )
    }

    private func makeAudioFixture() throws -> (directory: URL, audioURL: URL) {
        try makeAudioFixture(named: "solo.wav")
    }

    private func makeAudioFixture(named fileName: String) throws -> (directory: URL, audioURL: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiveSwitcherBGMCompletionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let audioURL = directory.appendingPathComponent(fileName)
        try writeSineWaveFixture(to: audioURL)
        return (directory, audioURL)
    }

    private func makeFallbackAudioFixture() throws -> (directory: URL, audioURL: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiveSwitcherBGMFallbackCompletionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let audioURL = directory.appendingPathComponent("fallback.mp3")
        try Data("not a decodable audio file".utf8).write(to: audioURL)
        return (directory, audioURL)
    }

    private func writeSineWaveFixture(to url: URL) throws {
        let sampleRate = 44_100.0
        let frameCount = AVAudioFrameCount(sampleRate / 4)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let channel = buffer.floatChannelData![0]
        for frame in 0..<Int(frameCount) {
            let phase = (Double(frame) / sampleRate) * 440.0 * 2.0 * Double.pi
            channel[frame] = Float(sin(phase) * 0.8)
        }

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }
}
