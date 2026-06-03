import XCTest
@testable import LiveSwitcher

@MainActor
final class MediaRuntimePanicBridgeTests: XCTestCase {
    func testPanicActivatePausesMediaThroughRuntimePort() {
        let media = MediaRuntimePanicPortSpy()
        let viewModel = viewModel(media: media)
        let item = mediaProgram()
        viewModel.liveAudioFadeDuration = 0
        viewModel.programItems = [item]
        viewModel.currentProgramItem = item
        viewModel.avCoordinator.isPlaying = true

        viewModel.togglePanicMode()

        XCTAssertTrue(media.events.contains { $0.hasPrefix("pause:") })
    }

    func testPanicDeactivateResumesMediaThroughRuntimePortWhenSnapshotMatches() {
        let media = MediaRuntimePanicPortSpy()
        let viewModel = viewModel(media: media)
        let item = mediaProgram()
        viewModel.liveAudioFadeDuration = 0
        viewModel.programItems = [item]
        viewModel.currentProgramItem = item
        viewModel.isPanicMode = true
        viewModel.panicPlaybackSnapshot = PanicPlaybackSnapshot(
            currentProgramID: item.id,
            wasMediaPlaying: true,
            currentBGMID: nil,
            wasBGMPlaying: false
        )

        viewModel.togglePanicMode()

        XCTAssertTrue(media.events.contains { $0.hasPrefix("volume:") && $0.contains(":0.0:") })
        XCTAssertTrue(media.events.contains { $0.hasPrefix("play:") })
    }

    func testPanicDeactivateDoesNotResumeMediaWhenProgramChanged() {
        let media = MediaRuntimePanicPortSpy()
        let viewModel = viewModel(media: media)
        let oldItem = mediaProgram()
        let newItem = mediaProgram()
        viewModel.liveAudioFadeDuration = 0
        viewModel.programItems = [oldItem, newItem]
        viewModel.currentProgramItem = newItem
        viewModel.isPanicMode = true
        viewModel.panicPlaybackSnapshot = PanicPlaybackSnapshot(
            currentProgramID: oldItem.id,
            wasMediaPlaying: true,
            currentBGMID: nil,
            wasBGMPlaying: false
        )

        viewModel.togglePanicMode()

        XCTAssertFalse(media.events.contains { $0.hasPrefix("play:") })
    }

    func testPanicDoesNotDirectlyCallAVPlayerForMedia() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Panic.swift")

        XCTAssertFalse(source.contains("avCoordinator.pause()"))
        XCTAssertFalse(source.contains("avCoordinator.play()"))
        XCTAssertFalse(source.contains("avCoordinator.volume = 0"))
    }

    func testBGMBehaviorRemainsViewModelOwnedInThisPR() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Panic.swift")

        XCTAssertTrue(source.contains("bgmAudioPlayer"))
        XCTAssertTrue(source.contains("bgmFallbackPlayer"))
    }

    private func viewModel(media: MediaRuntimePanicPortSpy) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, media: media),
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        )
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
    }

    private func mediaProgram() -> ProgramItem {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        try? Data("fixture".utf8).write(to: url)
        return ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: url)
    }

    private func sourceText(_ relativePath: String) throws -> String {
        let url = try repositoryRoot().appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            if FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("script/check_release_hygiene.sh").path
            ) {
                return directory
            }
        }
        throw XCTSkip("Could not locate repository root from test source path.")
    }
}

private final class MediaRuntimePanicPortSpy: MediaPlaybackPort {
    private(set) var events: [String] = []

    func load(url: URL, generation: Int) {
        events.append("load:\(generation)")
    }

    func play(generation: Int) {
        events.append("play:\(generation)")
    }

    func pause(generation: Int) {
        events.append("pause:\(generation)")
    }

    func restart(generation: Int) {
        events.append("restart:\(generation)")
    }

    func seekToStart(generation: Int) {
        events.append("seekToStart:\(generation)")
    }

    func seekToEnd(generation: Int) {
        events.append("seekToEnd:\(generation)")
    }

    func stop(generation: Int) {
        events.append("stop:\(generation)")
    }

    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) {
        events.append("volume:\(generation):\(volume):\(fade)")
    }
}
