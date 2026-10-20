import XCTest
import AVFoundation
@testable import LiveSwitcher

@MainActor
final class BGMRuntimeRetiredPlayerCleanupTests: XCTestCase {
    func testRetiredAVAudioPlayerCleanupRunsEvenAfterGenerationAdvances() async throws {
        let viewModel = makeViewModel()
        let retired = try AVAudioPlayer(contentsOf: makeAudioFixture())
        defer { retired.stop() }
        retired.delegate = viewModel.bgmDelegate
        XCTAssertTrue(retired.play())
        XCTAssertTrue(retired.isPlaying)
        XCTAssertNotNil(retired.delegate)
        let previousTaskIDs = Set(viewModel.cleanupBag.bgmTransitionTasks.keys)

        viewModel.releaseRetiredBGMPlayerAfterFade(retired, duration: 0.03)
        let taskID = try XCTUnwrap(Set(viewModel.cleanupBag.bgmTransitionTasks.keys).subtracting(previousTaskIDs).first)
        let task = try XCTUnwrap(viewModel.cleanupBag.bgmTransitionTasks[taskID])
        var state = viewModel.runtime.state
        state.bgm.generation += 1
        viewModel.runtime.replaceStateForFacadeSync(state)
        await task.value

        XCTAssertFalse(task.isCancelled)
        XCTAssertFalse(retired.isPlaying)
        XCTAssertNil(retired.delegate)
        XCTAssertNil(viewModel.cleanupBag.bgmTransitionTasks[taskID])
    }

    func testRetiredAVAudioPlayerCleanupDoesNotTouchCurrentPlayer() async throws {
        let viewModel = makeViewModel()
        let url = try makeAudioFixture()
        let current = try AVAudioPlayer(contentsOf: url)
        let retired = try AVAudioPlayer(contentsOf: url)
        defer { current.stop(); retired.stop() }
        current.volume = 0.7
        retired.volume = 0.3
        retired.delegate = viewModel.bgmDelegate
        viewModel.bgmAudioPlayer = current
        XCTAssertTrue(current.play())
        XCTAssertTrue(retired.play())
        XCTAssertTrue(current.isPlaying)
        XCTAssertTrue(retired.isPlaying)
        let previousTaskIDs = Set(viewModel.cleanupBag.bgmTransitionTasks.keys)

        viewModel.fadeRetiredBGMPlayerVolume(retired, to: 0, duration: 0.03)
        viewModel.releaseRetiredBGMPlayerAfterFade(retired, duration: 0.03)
        let taskIDs = Set(viewModel.cleanupBag.bgmTransitionTasks.keys).subtracting(previousTaskIDs)
        XCTAssertFalse(taskIDs.isEmpty)
        let tasks = try taskIDs.map { try XCTUnwrap(viewModel.cleanupBag.bgmTransitionTasks[$0]) }
        for task in tasks { await task.value }

        XCTAssertTrue(viewModel.bgmAudioPlayer === current)
        XCTAssertEqual(current.volume, 0.7, accuracy: 0.0001)
        XCTAssertTrue(current.isPlaying)
        XCTAssertEqual(retired.volume, 0, accuracy: 0.0001)
        XCTAssertFalse(retired.isPlaying)
        XCTAssertNil(retired.delegate)
        for taskID in taskIDs { XCTAssertNil(viewModel.cleanupBag.bgmTransitionTasks[taskID]) }
    }

    func testRetiredFallbackCleanupRunsEvenAfterGenerationAdvances() async throws {
        let viewModel = makeViewModel()
        let retired = AVPlayer(playerItem: AVPlayerItem(url: try makeAudioFixture()))
        retired.volume = 0.5
        viewModel.bgmFallbackPlayer = retired
        XCTAssertNotNil(retired.currentItem)
        let previousTaskIDs = Set(viewModel.cleanupBag.bgmTransitionTasks.keys)

        viewModel.retireCurrentBGMFallbackPlayerForSwitch(duration: 0.03)
        let taskID = try XCTUnwrap(Set(viewModel.cleanupBag.bgmTransitionTasks.keys).subtracting(previousTaskIDs).first)
        let task = try XCTUnwrap(viewModel.cleanupBag.bgmTransitionTasks[taskID])
        XCTAssertFalse(viewModel.bgmFallbackPlayer === retired)
        XCTAssertTrue(viewModel.cleanupBag.retiredBGMFallbackPlayers[taskID] === retired)
        var state = viewModel.runtime.state
        state.bgm.generation += 1
        viewModel.runtime.replaceStateForFacadeSync(state)
        await task.value

        XCTAssertFalse(task.isCancelled)
        XCTAssertEqual(retired.volume, 0)
        XCTAssertEqual(retired.rate, 0)
        XCTAssertNil(retired.currentItem)
        XCTAssertNil(viewModel.cleanupBag.retiredBGMFallbackPlayers[taskID])
        XCTAssertNil(viewModel.cleanupBag.bgmTransitionTasks[taskID])
    }

    func testRetiredFallbackCleanupDoesNotTouchCurrentFallbackPlayer() async throws {
        let viewModel = makeViewModel()
        let url = try makeAudioFixture()
        let retired = AVPlayer(playerItem: AVPlayerItem(url: url))
        retired.volume = 0.4
        viewModel.bgmFallbackPlayer = retired
        XCTAssertNotNil(retired.currentItem)
        let previousTaskIDs = Set(viewModel.cleanupBag.bgmTransitionTasks.keys)

        viewModel.retireCurrentBGMFallbackPlayerForSwitch(duration: 0.03)
        let taskID = try XCTUnwrap(Set(viewModel.cleanupBag.bgmTransitionTasks.keys).subtracting(previousTaskIDs).first)
        let task = try XCTUnwrap(viewModel.cleanupBag.bgmTransitionTasks[taskID])
        let current = viewModel.bgmFallbackPlayer
        let currentItem = AVPlayerItem(url: url)
        current.replaceCurrentItem(with: currentItem)
        current.volume = 0.8
        defer { current.pause(); current.replaceCurrentItem(with: nil) }
        XCTAssertFalse(current === retired)
        XCTAssertTrue(viewModel.cleanupBag.retiredBGMFallbackPlayers[taskID] === retired)
        await task.value

        XCTAssertTrue(viewModel.bgmFallbackPlayer === current)
        XCTAssertTrue(current.currentItem === currentItem)
        XCTAssertEqual(current.volume, 0.8, accuracy: 0.0001)
        XCTAssertEqual(retired.volume, 0)
        XCTAssertEqual(retired.rate, 0)
        XCTAssertNil(retired.currentItem)
        XCTAssertNil(viewModel.cleanupBag.retiredBGMFallbackPlayers[taskID])
        XCTAssertNil(viewModel.cleanupBag.bgmTransitionTasks[taskID])
    }

    func testRapidBGM_A_B_C_StopsRetiredAAndB() async throws {
        let viewModel = makeViewModel()
        let items = try ["A", "B", "C"].map { title in
            BGMItem(title: title, url: try makeAudioFixture(), category: .warmUp)
        }
        viewModel.bgmItems = items
        viewModel.liveAudioFadeDuration = 0.03
        viewModel.dispatchRuntimeFacadeAction(.operatorSelectedBGMPlayMode(.loopOne))
        defer { viewModel.bgmAudioPlayer?.stop() }
        let previousTaskIDs = Set(viewModel.cleanupBag.bgmTransitionTasks.keys)

        viewModel.toggleBGM(items[0])
        let first = try XCTUnwrap(viewModel.bgmAudioPlayer)
        XCTAssertTrue(first.isPlaying)
        viewModel.toggleBGM(items[1])
        let second = try XCTUnwrap(viewModel.bgmAudioPlayer)
        XCTAssertTrue(second.isPlaying)
        viewModel.toggleBGM(items[2])
        let taskIDs = Set(viewModel.cleanupBag.bgmTransitionTasks.keys).subtracting(previousTaskIDs)
        XCTAssertFalse(taskIDs.isEmpty)
        let tasks = try taskIDs.map { try XCTUnwrap(viewModel.cleanupBag.bgmTransitionTasks[$0]) }
        let currentFade = try XCTUnwrap(viewModel.cleanupBag.bgmPlayerVolumeFadeTask)
        let fallbackFade = try XCTUnwrap(viewModel.cleanupBag.bgmFallbackVolumeFadeTask)
        for task in tasks { await task.value }
        await currentFade.value
        await fallbackFade.value

        XCTAssertFalse(first.isPlaying)
        XCTAssertFalse(second.isPlaying)
        XCTAssertNil(first.delegate)
        XCTAssertNil(second.delegate)
        for taskID in taskIDs { XCTAssertNil(viewModel.cleanupBag.bgmTransitionTasks[taskID]) }
    }

    func testRapidBGM_A_B_C_LeavesOnlyCActive() async throws {
        let viewModel = makeViewModel()
        let items = try ["A", "B", "C"].map { title in
            BGMItem(title: title, url: try makeAudioFixture(), category: .warmUp)
        }
        viewModel.bgmItems = items
        viewModel.liveAudioFadeDuration = 0.03
        viewModel.dispatchRuntimeFacadeAction(.operatorSelectedBGMPlayMode(.loopOne))
        defer { viewModel.bgmAudioPlayer?.stop() }
        let previousTaskIDs = Set(viewModel.cleanupBag.bgmTransitionTasks.keys)

        viewModel.toggleBGM(items[0])
        let first = try XCTUnwrap(viewModel.bgmAudioPlayer)
        XCTAssertTrue(first.isPlaying)
        viewModel.toggleBGM(items[1])
        let second = try XCTUnwrap(viewModel.bgmAudioPlayer)
        XCTAssertTrue(second.isPlaying)
        viewModel.toggleBGM(items[2])
        let third = try XCTUnwrap(viewModel.bgmAudioPlayer)
        XCTAssertTrue(third.isPlaying)
        let targetVolume = viewModel.runtime.state.audio.effectiveBGM
        let taskIDs = Set(viewModel.cleanupBag.bgmTransitionTasks.keys).subtracting(previousTaskIDs)
        XCTAssertFalse(taskIDs.isEmpty)
        let tasks = try taskIDs.map { try XCTUnwrap(viewModel.cleanupBag.bgmTransitionTasks[$0]) }
        let currentFade = try XCTUnwrap(viewModel.cleanupBag.bgmPlayerVolumeFadeTask)
        let fallbackFade = try XCTUnwrap(viewModel.cleanupBag.bgmFallbackVolumeFadeTask)
        for task in tasks { await task.value }
        await currentFade.value
        await fallbackFade.value

        XCTAssertTrue(viewModel.bgmAudioPlayer === third)
        XCTAssertEqual(viewModel.currentBGMItem?.id, items[2].id)
        XCTAssertTrue(third.isPlaying)
        XCTAssertEqual(third.volume, targetVolume, accuracy: 0.0001)
        XCTAssertFalse(first.isPlaying)
        XCTAssertFalse(second.isPlaying)
        XCTAssertNil(first.delegate)
        XCTAssertNil(second.delegate)
        for taskID in taskIDs { XCTAssertNil(viewModel.cleanupBag.bgmTransitionTasks[taskID]) }
    }

    func testCurrentBGMVolumeFadeIsGenerationGuarded() async throws {
        let viewModel = makeViewModel()
        let current = try AVAudioPlayer(contentsOf: makeAudioFixture())
        viewModel.bgmAudioPlayer = current
        var state = viewModel.runtime.state
        state.bgm.generation = 2
        viewModel.runtime.replaceStateForFacadeSync(state)

        for duration in [0.0, 0.03] {
            current.volume = 0.8
            viewModel.fadeCurrentBGMPlayerVolume(to: 0.1, duration: duration, generation: 1)
            if duration > 0 {
                let staleTask = try XCTUnwrap(viewModel.cleanupBag.bgmPlayerVolumeFadeTask)
                await staleTask.value
            }
            XCTAssertEqual(current.volume, 0.8, accuracy: 0.0001)

            viewModel.fadeCurrentBGMPlayerVolume(to: 0.4, duration: duration, generation: state.bgm.generation)
            if duration > 0 {
                let currentTask = try XCTUnwrap(viewModel.cleanupBag.bgmPlayerVolumeFadeTask)
                await currentTask.value
            }
            XCTAssertTrue(viewModel.bgmAudioPlayer === current)
            XCTAssertEqual(current.volume, 0.4, accuracy: 0.0001)
        }
    }

    func testRetiredBGMVolumeFadeIsNotSkippedByNewGeneration() async throws {
        let viewModel = makeViewModel()
        let url = try makeAudioFixture()
        let current = try AVAudioPlayer(contentsOf: url)
        let retired = try AVAudioPlayer(contentsOf: url)
        current.volume = 0.7
        retired.volume = 1
        viewModel.bgmAudioPlayer = current
        let previousTaskIDs = Set(viewModel.cleanupBag.bgmTransitionTasks.keys)

        viewModel.fadeRetiredBGMPlayerVolume(retired, to: 0, duration: 0.03)
        let taskID = try XCTUnwrap(Set(viewModel.cleanupBag.bgmTransitionTasks.keys).subtracting(previousTaskIDs).first)
        let task = try XCTUnwrap(viewModel.cleanupBag.bgmTransitionTasks[taskID])
        var state = viewModel.runtime.state
        state.bgm.generation += 1
        viewModel.runtime.replaceStateForFacadeSync(state)
        await task.value

        XCTAssertFalse(task.isCancelled)
        XCTAssertEqual(retired.volume, 0, accuracy: 0.0001)
        XCTAssertTrue(viewModel.bgmAudioPlayer === current)
        XCTAssertEqual(current.volume, 0.7, accuracy: 0.0001)
        XCTAssertNil(viewModel.cleanupBag.bgmTransitionTasks[taskID])
    }

    func testReleaseRetiredBGMPlayerAfterFadeDoesNotGuardOnCurrentGeneration() throws {
        let source = try sourceText("BGMPlayback/BGMPlayerFade.swift")
        let body = try functionBody(named: "releaseRetiredBGMPlayerAfterFade", in: source)

        XCTAssertFalse(body.contains("runtime.state.bgm.generation"))
        XCTAssertFalse(body.contains("bgmTransitionGeneration == generation"))
    }

    func testCurrentBGMFadeHelperDoesGuardOnGeneration() throws {
        let source = try sourceText("BGMPlayback/BGMPlayerFade.swift")
        let body = try functionBody(named: "fadeCurrentBGMPlayerVolume", in: source)

        XCTAssertTrue(body.contains("runtime.state.bgm.generation"))
        XCTAssertTrue(body.contains("generation"))
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "BGMRuntimeRetiredPlayerCleanupTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
    }

    private func makeAudioFixture() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BGMRuntimeRetiredPlayerCleanupTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("cleanup.wav")
        try BGMAudioFixture.writeSineWave(to: url, duration: 20)
        return url
    }

    private func functionBody(named name: String, in source: String) throws -> String {
        guard let start = source.range(of: "func \(name)") ?? source.range(of: "private func \(name)") else {
            XCTFail("Function \(name) not found")
            return ""
        }
        guard let bodyStart = source[start.lowerBound...].firstIndex(of: "{") else {
            XCTFail("Function \(name) body not found")
            return ""
        }
        var depth = 0
        var index = bodyStart
        while index < source.endIndex {
            if source[index] == "{" { depth += 1 }
            if source[index] == "}" {
                depth -= 1
                if depth == 0 {
                    return String(source[start.lowerBound...index])
                }
            }
            index = source.index(after: index)
        }
        XCTFail("Function \(name) body was not closed")
        return ""
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) -> URL {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let candidates = [
            packageRoot.appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher").appendingPathComponent(relativePath),
            packageRoot.appendingPathComponent("Sources/AnnualMeetingSwitcher").appendingPathComponent(relativePath),
            packageRoot.appendingPathComponent(relativePath)
        ]
        if let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return url
        }
        return candidates[0]
    }
}

enum BGMAudioFixture {
    static func writeSineWave(to url: URL, duration: Double = 0.25) throws {
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
