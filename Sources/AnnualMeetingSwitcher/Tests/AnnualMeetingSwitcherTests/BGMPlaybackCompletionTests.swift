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

    private func makeViewModel() -> SwitcherViewModel {
        SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: .standard
        )
    }

    private func makeAudioFixture() throws -> (directory: URL, audioURL: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiveSwitcherBGMCompletionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let audioURL = directory.appendingPathComponent("solo.wav")
        try writeSineWaveFixture(to: audioURL)
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
