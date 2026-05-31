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

    func testSequentialFinishInvalidatesBGMTransitionGeneration() throws {
        let (directory, audioURL) = try makeAudioFixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let item = BGMItem(title: "Solo", url: audioURL, category: .warmUp)
        let viewModel = makeViewModel()
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)
        viewModel.bgmPlayMode = .sequential
        let generationBeforeFinish = viewModel.bgmTransitionGenerationForTesting

        viewModel.bgmDidFinish()

        XCTAssertGreaterThan(viewModel.bgmTransitionGenerationForTesting, generationBeforeFinish)
        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertNil(viewModel.bgmAudioPlayer)
        XCTAssertEqual(viewModel.bgmProgress, 0)
    }

    func testBGMFailureInvalidatesBGMTransitionGeneration() throws {
        let (directory, audioURL) = try makeAudioFixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let item = BGMItem(title: "Failure Tail", url: audioURL, category: .warmUp)
        let viewModel = makeViewModel()
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)
        let generationBeforeFailure = viewModel.bgmTransitionGenerationForTesting

        viewModel.bgmDidFail()

        XCTAssertGreaterThan(viewModel.bgmTransitionGenerationForTesting, generationBeforeFailure)
        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertNil(viewModel.bgmAudioPlayer)
        XCTAssertEqual(viewModel.bgmProgress, 0)
    }

    func testPanicBGMStopAndRestoreInvalidateBGMTransitionGeneration() throws {
        let (directory, audioURL) = try makeAudioFixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let item = BGMItem(title: "Panic BGM", url: audioURL, category: .warmUp)
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)
        let generationBeforePanic = viewModel.bgmTransitionGenerationForTesting

        viewModel.togglePanicMode()

        XCTAssertGreaterThan(viewModel.bgmTransitionGenerationForTesting, generationBeforePanic)
        XCTAssertFalse(viewModel.isBGMPlaying)

        let generationBeforeRestore = viewModel.bgmTransitionGenerationForTesting
        viewModel.togglePanicMode()

        XCTAssertGreaterThan(viewModel.bgmTransitionGenerationForTesting, generationBeforeRestore)
        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertEqual(viewModel.currentBGMItem?.id, item.id)
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

    func testBGMFinishedDuringPanicClearsPlayerBeforeReplay() throws {
        let (directory, audioURL) = try makeAudioFixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let item = BGMItem(title: "Panic Tail", url: audioURL, category: .warmUp)
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.bgmItems = [item]

        viewModel.toggleBGM(item)
        let finishedPlayer = try XCTUnwrap(viewModel.bgmAudioPlayer)

        viewModel.togglePanicMode()
        viewModel.bgmDidFinish(from: finishedPlayer)

        XCTAssertTrue(viewModel.isPanicMode)
        XCTAssertEqual(viewModel.currentBGMItem?.id, item.id)
        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertNil(viewModel.bgmAudioPlayer)

        viewModel.togglePanicMode()
        XCTAssertFalse(viewModel.isBGMPlaying)

        viewModel.toggleBGM(item)

        XCTAssertTrue(viewModel.isBGMPlaying)
        let replayPlayer = try XCTUnwrap(viewModel.bgmAudioPlayer)
        XCTAssertFalse(replayPlayer === finishedPlayer)
        XCTAssertEqual(replayPlayer.currentTime, 0, accuracy: 0.1)
    }

    func testFallbackBGMFinishedDuringPanicClearsItemBeforeReplay() throws {
        let (directory, audioURL) = try makeFallbackAudioFixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let item = BGMItem(title: "Fallback Panic Tail", url: audioURL, category: .warmUp)
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.bgmItems = [item]

        viewModel.toggleBGM(item)
        XCTAssertNil(viewModel.bgmAudioPlayer)
        XCTAssertNotNil(viewModel.bgmFallbackPlayer.currentItem)

        viewModel.togglePanicMode()
        viewModel.bgmDidFinish()

        XCTAssertTrue(viewModel.isPanicMode)
        XCTAssertEqual(viewModel.currentBGMItem?.id, item.id)
        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertNil(viewModel.bgmFallbackPlayer.currentItem)

        viewModel.togglePanicMode()
        XCTAssertFalse(viewModel.isBGMPlaying)

        viewModel.toggleBGM(item)

        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertNotNil(viewModel.bgmFallbackPlayer.currentItem)
    }

    func testBGMFailureDuringPanicPreventsAutomaticResume() throws {
        let (directory, audioURL) = try makeAudioFixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let item = BGMItem(title: "Panic Failure", url: audioURL, category: .warmUp)
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.bgmItems = [item]

        viewModel.toggleBGM(item)
        let failedPlayer = try XCTUnwrap(viewModel.bgmAudioPlayer)

        viewModel.togglePanicMode()
        viewModel.bgmDidFail(from: failedPlayer)

        XCTAssertTrue(viewModel.isPanicMode)
        XCTAssertEqual(viewModel.currentBGMItem?.id, item.id)
        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertNil(viewModel.bgmAudioPlayer)

        viewModel.togglePanicMode()

        XCTAssertFalse(viewModel.isPanicMode)
        XCTAssertFalse(viewModel.isBGMPlaying)
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

    func testRapidAudioPlayerSwitchesLeaveOnlyLatestTrackActive() async throws {
        let (directory, firstURL) = try makeAudioFixture(named: "first.wav", duration: 1.5)
        let secondURL = directory.appendingPathComponent("second.wav")
        let thirdURL = directory.appendingPathComponent("third.wav")
        try writeSineWaveFixture(to: secondURL, duration: 1.5)
        try writeSineWaveFixture(to: thirdURL, duration: 1.5)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = BGMItem(title: "First", url: firstURL, category: .warmUp)
        let second = BGMItem(title: "Second", url: secondURL, category: .warmUp)
        let third = BGMItem(title: "Third", url: thirdURL, category: .warmUp)
        let viewModel = makeViewModel()
        viewModel.bgmItems = [first, second, third]
        viewModel.liveAudioFadeDuration = 0.15

        viewModel.toggleBGM(first)
        let firstPlayer = try XCTUnwrap(viewModel.bgmAudioPlayer)
        viewModel.toggleBGM(second)
        let secondPlayer = try XCTUnwrap(viewModel.bgmAudioPlayer)
        viewModel.toggleBGM(third)

        XCTAssertEqual(viewModel.currentBGMItem?.id, third.id)
        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertFalse(viewModel.bgmAudioPlayer === firstPlayer)
        XCTAssertFalse(viewModel.bgmAudioPlayer === secondPlayer)

        viewModel.bgmDelegate.audioPlayerDidFinishPlaying(firstPlayer, successfully: true)
        viewModel.bgmDelegate.audioPlayerDidFinishPlaying(secondPlayer, successfully: false)
        try await Task.sleep(nanoseconds: 250_000_000)

        XCTAssertEqual(viewModel.currentBGMItem?.id, third.id)
        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertNotNil(viewModel.bgmAudioPlayer)
    }

    func testBGMDecodeErrorStopsCurrentPlayback() async throws {
        let (directory, audioURL) = try makeAudioFixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let item = BGMItem(title: "Decode Tail", url: audioURL, category: .warmUp)
        let viewModel = makeViewModel()
        viewModel.bgmItems = [item]

        viewModel.toggleBGM(item)
        let failedPlayer = try XCTUnwrap(viewModel.bgmAudioPlayer)

        viewModel.bgmDelegate.audioPlayerDecodeErrorDidOccur(failedPlayer, error: nil)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertNil(viewModel.bgmAudioPlayer)
        XCTAssertNil(viewModel.bgmFallbackPlayer.currentItem)
    }

    func testPausedBGMFinishDuringFadeDoesNotAdvanceToNextTrack() async throws {
        let (directory, firstURL) = try makeAudioFixture(named: "first.wav")
        let secondURL = directory.appendingPathComponent("second.wav")
        try writeSineWaveFixture(to: secondURL)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = BGMItem(title: "First", url: firstURL, category: .warmUp)
        let second = BGMItem(title: "Second", url: secondURL, category: .warmUp)
        let viewModel = makeViewModel()
        viewModel.bgmItems = [first, second]
        viewModel.bgmPlayMode = .loopAll
        viewModel.liveAudioFadeDuration = 1.0

        viewModel.toggleBGM(first)
        let pausedPlayer = try XCTUnwrap(viewModel.bgmAudioPlayer)

        viewModel.toggleBGM(first)
        XCTAssertFalse(viewModel.isBGMPlaying)

        viewModel.bgmDelegate.audioPlayerDidFinishPlaying(pausedPlayer, successfully: true)
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.currentBGMItem?.id, first.id)
        XCTAssertFalse(viewModel.isBGMPlaying)
    }

    func testResumingSelectedBGMAtEndRestartsFromBeginning() throws {
        let (directory, audioURL) = try makeAudioFixture()
        defer { try? FileManager.default.removeItem(at: directory) }
        let item = BGMItem(title: "At End", url: audioURL, category: .warmUp)
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        viewModel.bgmItems = [item]

        viewModel.toggleBGM(item)
        let player = try XCTUnwrap(viewModel.bgmAudioPlayer)
        player.currentTime = player.duration
        viewModel.toggleBGM(item)
        XCTAssertFalse(viewModel.isBGMPlaying)

        viewModel.toggleBGM(item)

        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertLessThan(player.currentTime, 0.05)
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

    private func makeAudioFixture(named fileName: String, duration: Double = 0.25) throws -> (directory: URL, audioURL: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiveSwitcherBGMCompletionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let audioURL = directory.appendingPathComponent(fileName)
        try writeSineWaveFixture(to: audioURL, duration: duration)
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

    private func writeSineWaveFixture(to url: URL, duration: Double = 0.25) throws {
        let sampleRate = 44_100.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
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
