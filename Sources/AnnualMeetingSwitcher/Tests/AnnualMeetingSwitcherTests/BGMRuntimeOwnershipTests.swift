import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMRuntimeOwnershipTests: XCTestCase {
    func testToggleBGMSelectsTrackThroughRuntimePort() {
        let first = bgmItem(title: "First")
        let ports = BGMRuntimeOwnershipPorts()
        let viewModel = makeViewModel(ports: ports)
        viewModel.bgmItems = [first]

        viewModel.toggleBGM(first)

        XCTAssertEqual(ports.bgm.events, [.prepare(first.id, 1), .play(1)])
        XCTAssertEqual(ports.timer.events, [.start(1)])
    }

    func testToggleCurrentPlayingBGMStopsThroughRuntimePort() {
        let item = bgmItem(title: "Walk-in")
        let ports = BGMRuntimeOwnershipPorts()
        let viewModel = makeViewModel(ports: ports)
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)
        ports.reset()

        viewModel.toggleBGM(item)

        XCTAssertEqual(ports.bgm.events, [.stop(2.0, 2)])
        XCTAssertEqual(ports.timer.events, [.stop(2)])
    }

    func testToggleCurrentPausedBGMPlaysThroughRuntimePort() {
        let item = bgmItem(title: "Walk-in")
        let ports = BGMRuntimeOwnershipPorts()
        let viewModel = makeViewModel(ports: ports)
        viewModel.bgmItems = [item]
        viewModel.currentBGMItem = item
        viewModel.isBGMPlaying = false

        viewModel.toggleBGM(item)

        XCTAssertEqual(ports.bgm.events, [.prepare(item.id, 1), .play(1)])
        XCTAssertEqual(ports.timer.events, [.start(1)])
    }

    func testPlayNextBGMUsesRuntimeReducerAndPort() {
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        let ports = BGMRuntimeOwnershipPorts()
        let viewModel = makeViewModel(ports: ports)
        viewModel.bgmItems = [first, second]
        viewModel.toggleBGM(first)
        ports.reset()

        viewModel.playNextBGM()

        XCTAssertEqual(viewModel.currentBGMItem?.id, second.id)
        XCTAssertEqual(ports.bgm.events, [.prepare(second.id, 2), .play(2)])
        XCTAssertEqual(ports.timer.events, [.start(2)])
    }

    func testPlayPreviousBGMUsesRuntimeReducerAndPort() {
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        let ports = BGMRuntimeOwnershipPorts()
        let viewModel = makeViewModel(ports: ports)
        viewModel.bgmItems = [first, second]
        viewModel.toggleBGM(second)
        ports.reset()

        viewModel.playPreviousBGM()

        XCTAssertEqual(viewModel.currentBGMItem?.id, first.id)
        XCTAssertEqual(ports.bgm.events, [.prepare(first.id, 2), .play(2)])
        XCTAssertEqual(ports.timer.events, [.start(2)])
    }

    func testRemoveCurrentBGMStopsThroughRuntimePort() {
        let item = bgmItem(title: "Walk-in")
        let ports = BGMRuntimeOwnershipPorts()
        let viewModel = makeViewModel(ports: ports)
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)
        ports.reset()

        viewModel.removeBGMItem(item)

        XCTAssertEqual(ports.bgm.events, [.stop(2.0, 2)])
        XCTAssertEqual(ports.timer.events, [.stop(2)])
    }

    func testBGMDidFinishDispatchesRuntimeReachedEnd() {
        let item = bgmItem(title: "Walk-in")
        let ports = BGMRuntimeOwnershipPorts()
        let viewModel = makeViewModel(ports: ports)
        viewModel.bgmItems = [item]
        viewModel.bgmPlayMode = .sequential
        viewModel.toggleBGM(item)
        viewModel.seedActiveRuntimeBGMCallbackForTesting(item: item, generation: 1)
        ports.reset()

        viewModel.bgmDidFinish()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "bgmReachedEnd" })
        XCTAssertEqual(ports.bgm.events, [.stop(0, 2)])
        XCTAssertEqual(ports.timer.events, [.stop(2)])
    }

    func testBGMDidFailDispatchesRuntimeFailure() {
        let item = bgmItem(title: "Walk-in")
        let ports = BGMRuntimeOwnershipPorts()
        let viewModel = makeViewModel(ports: ports)
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)
        viewModel.seedActiveRuntimeBGMCallbackForTesting(item: item, generation: 1)
        ports.reset()

        viewModel.bgmDidFail()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "bgmFailed" })
        XCTAssertEqual(ports.bgm.events, [.stop(0, 2)])
        XCTAssertEqual(ports.timer.events, [.stop(2)])
    }

    func testNoBGMPlayerCreationInToggleBGM() throws {
        try testViewModelDoesNotDirectlyCreateAVAudioPlayerInToggleBGM()
    }

    func testNoFallbackReplaceInToggleBGM() throws {
        try testViewModelDoesNotDirectlyReplaceFallbackPlayerInToggleBGM()
    }

    func testNoTimerStartStopInToggleBGM() throws {
        try testViewModelDoesNotDirectlyStartStopBGMTimerInToggleBGM()
    }

    func testViewModelDoesNotDirectlyCreateAVAudioPlayerInToggleBGM() throws {
        let body = try toggleBGMBody()

        XCTAssertFalse(body.contains("AVAudioPlayer(contentsOf:"))
    }

    func testViewModelDoesNotDirectlyReplaceFallbackPlayerInToggleBGM() throws {
        let body = try toggleBGMBody()

        XCTAssertFalse(body.contains("bgmFallbackPlayer.replaceCurrentItem"))
    }

    func testViewModelDoesNotDirectlyStartStopBGMTimerInToggleBGM() throws {
        let body = try toggleBGMBody()

        XCTAssertFalse(body.contains("startBGMTimer()"))
        XCTAssertFalse(body.contains("stopBGMTimer()"))
    }

    private func toggleBGMBody() throws -> String {
        let source = try sourceText("ViewModel+BGMControls.swift")
        guard let start = source.range(of: "    func toggleBGM(_ item: BGMItem) {"),
              let end = source.range(of: "    private func cueBGMDuringPanic", range: start.upperBound..<source.endIndex)
        else {
            XCTFail("toggleBGM body not found")
            return ""
        }
        return String(source[start.upperBound..<end.lowerBound])
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
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

    private func makeViewModel(ports: BGMRuntimeOwnershipPorts) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(
                recordsOnly: false,
                bgm: ports.bgm,
                bgmTimer: ports.timer
            ),
            environment: .productionBGMOwning()
        )
        let suiteName = "BGMRuntimeOwnershipTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults,
            runtime: runtime
        )
    }

    private func bgmItem(title: String) -> BGMItem {
        BGMItem(title: title, url: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).mp3"))
    }
}

private final class BGMRuntimeOwnershipPorts {
    let bgm = BGMRuntimeOwnershipPlaybackPort()
    let timer = BGMRuntimeOwnershipTimerPort()

    func reset() {
        bgm.events.removeAll()
        timer.events.removeAll()
    }
}

private final class BGMRuntimeOwnershipPlaybackPort: BGMPlaybackPort {
    enum Event: Equatable {
        case prepare(UUID, Int)
        case play(Int)
        case stop(TimeInterval, Int)
    }

    var events: [Event] = []

    func prepare(item: BGMItem, generation: Int) { events.append(.prepare(item.id, generation)) }
    func play(generation: Int) { events.append(.play(generation)) }
    func pause(generation: Int) {}
    func stop(fade: TimeInterval, generation: Int) { events.append(.stop(fade, generation)) }
    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) {}
    func seekToBeginning(generation: Int) {}
    func seek(toProgress progress: Double, generation: Int) {}
    func setPlayMode(_ playMode: BGMPlayMode, generation: Int?) {}
}

private final class BGMRuntimeOwnershipTimerPort: BGMTimerPort {
    enum Event: Equatable {
        case start(Int)
        case stop(Int)
    }

    var events: [Event] = []

    func start(generation: Int) { events.append(.start(generation)) }
    func stop(generation: Int) { events.append(.stop(generation)) }
}
