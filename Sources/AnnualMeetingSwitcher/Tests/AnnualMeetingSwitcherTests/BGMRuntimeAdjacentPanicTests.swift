import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMRuntimeAdjacentPanicTests: XCTestCase {
    func testNextBGMDuringPanicDoesNotPlayBGM() {
        let fixture = adjacentFixture(currentIndex: 0, panicActive: true)

        let mutation = reduce(fixture.state, .operatorSelectedNextBGM)

        XCTAssertFalse(mutation.state.bgm.isPlaying)
        XCTAssertFalse(mutation.effects.contains { if case .playBGM = $0 { return true }; return false })
    }

    func testPreviousBGMDuringPanicDoesNotPlayBGM() {
        let fixture = adjacentFixture(currentIndex: 1, panicActive: true)

        let mutation = reduce(fixture.state, .operatorSelectedPreviousBGM)

        XCTAssertFalse(mutation.state.bgm.isPlaying)
        XCTAssertFalse(mutation.effects.contains { if case .playBGM = $0 { return true }; return false })
    }

    func testNextBGMDuringPanicStopsBGMWithZeroFade() {
        let fixture = adjacentFixture(currentIndex: 0, panicActive: true)

        let mutation = reduce(fixture.state, .operatorSelectedNextBGM)

        XCTAssertTrue(mutation.effects.contains(.stopBGM(fade: 0, generation: 8)))
    }

    func testPreviousBGMDuringPanicStopsBGMWithZeroFade() {
        let fixture = adjacentFixture(currentIndex: 1, panicActive: true)

        let mutation = reduce(fixture.state, .operatorSelectedPreviousBGM)

        XCTAssertTrue(mutation.effects.contains(.stopBGM(fade: 0, generation: 8)))
    }

    func testNextBGMDuringPanicStopsBGMTimer() {
        let fixture = adjacentFixture(currentIndex: 0, panicActive: true)

        let mutation = reduce(fixture.state, .operatorSelectedNextBGM)

        XCTAssertTrue(mutation.effects.contains(.stopBGMTimer(generation: 8)))
    }

    func testNextBGMDuringPanicDoesNotPrepareBGM() {
        let fixture = adjacentFixture(currentIndex: 0, panicActive: true)

        let mutation = reduce(fixture.state, .operatorSelectedNextBGM)

        XCTAssertFalse(mutation.effects.contains { if case .prepareBGM = $0 { return true }; return false })
    }

    func testNextBGMDuringPanicDoesNotStartBGMTimer() {
        let fixture = adjacentFixture(currentIndex: 0, panicActive: true)

        let mutation = reduce(fixture.state, .operatorSelectedNextBGM)

        XCTAssertFalse(mutation.effects.contains { if case .startBGMTimer = $0 { return true }; return false })
    }

    func testNextBGMDuringPanicAppliesAudioRouting() {
        let fixture = adjacentFixture(currentIndex: 0, panicActive: true)

        let mutation = reduce(fixture.state, .operatorSelectedNextBGM)

        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .bgmPlaybackChanged)))
    }

    func testNextBGMDuringPanicMarksOldSnapshotBGMStopped() {
        let fixture = adjacentFixture(currentIndex: 0, panicActive: true)

        let mutation = reduce(fixture.state, .operatorSelectedNextBGM)

        XCTAssertFalse(mutation.state.panic.snapshot?.wasBGMPlaying == true)
    }

    func testPanicOffDoesNotResumeOldBGMAfterNextDuringPanic() {
        let fixture = adjacentFixture(currentIndex: 0, panicActive: true)

        let next = reduce(fixture.state, .operatorSelectedNextBGM)
        let off = reduce(next.state, .operatorSetPanic(false))

        XCTAssertFalse(off.state.bgm.isPlaying)
        XCTAssertFalse(off.effects.contains { if case .playBGM = $0 { return true }; return false })
    }

    func testNextBGMOutsidePanicStillPreparesPlaysAndStartsTimer() {
        let fixture = adjacentFixture(currentIndex: 0, panicActive: false)

        let mutation = reduce(fixture.state, .operatorSelectedNextBGM)

        XCTAssertEqual(mutation.state.bgm.currentID, fixture.second.id)
        XCTAssertTrue(mutation.state.bgm.isPlaying)
        XCTAssertTrue(mutation.effects.contains(.prepareBGM(fixture.second, generation: 8)))
        XCTAssertTrue(mutation.effects.contains(.playBGM(generation: 8)))
        XCTAssertTrue(mutation.effects.contains(.startBGMTimer(generation: 8)))
    }

    func testPreviousBGMOutsidePanicStillPreparesPlaysAndStartsTimer() {
        let fixture = adjacentFixture(currentIndex: 1, panicActive: false)

        let mutation = reduce(fixture.state, .operatorSelectedPreviousBGM)

        XCTAssertEqual(mutation.state.bgm.currentID, fixture.first.id)
        XCTAssertTrue(mutation.state.bgm.isPlaying)
        XCTAssertTrue(mutation.effects.contains(.prepareBGM(fixture.first, generation: 8)))
        XCTAssertTrue(mutation.effects.contains(.playBGM(generation: 8)))
        XCTAssertTrue(mutation.effects.contains(.startBGMTimer(generation: 8)))
    }

    func testViewModelNextBGMDuringPanicDoesNotPlayBGM() {
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        let ports = AdjacentPanicPorts()
        let viewModel = makeViewModel(ports: ports)
        viewModel.bgmItems = [first, second]
        viewModel.toggleBGM(first)
        viewModel.togglePanicMode()
        ports.reset()

        viewModel.playNextBGM()

        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertFalse(ports.bgm.events.contains { if case .play = $0 { return true }; return false })
    }

    func testViewModelPreviousBGMDuringPanicDoesNotPlayBGM() {
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        let ports = AdjacentPanicPorts()
        let viewModel = makeViewModel(ports: ports)
        viewModel.bgmItems = [first, second]
        viewModel.toggleBGM(second)
        viewModel.togglePanicMode()
        ports.reset()

        viewModel.playPreviousBGM()

        XCTAssertFalse(viewModel.isBGMPlaying)
        XCTAssertFalse(ports.bgm.events.contains { if case .play = $0 { return true }; return false })
    }

    func testViewModelNextBGMDuringPanicDoesNotUseViewModelSpecialCase() throws {
        let body = try viewModelBGMControlBody(named: "playNextBGM")

        XCTAssertFalse(body.contains("isPanicMode"))
        XCTAssertFalse(body.localizedStandardContains("panic"))
        XCTAssertFalse(body.localizedStandardContains("cue"))
        XCTAssertFalse(body.contains("stopBGM"))
    }

    func testViewModelPreviousBGMDuringPanicDoesNotUseViewModelSpecialCase() throws {
        let body = try viewModelBGMControlBody(named: "playPreviousBGM")

        XCTAssertFalse(body.contains("isPanicMode"))
        XCTAssertFalse(body.localizedStandardContains("panic"))
        XCTAssertFalse(body.localizedStandardContains("cue"))
        XCTAssertFalse(body.contains("stopBGM"))
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100), liveAudioFadeDuration: 0)
        )
    }

    private func adjacentFixture(currentIndex: Int, panicActive: Bool) -> (state: LiveRuntimeState, first: BGMItem, second: BGMItem) {
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        let current = currentIndex == 0 ? first : second
        var state = LiveRuntimeState()
        state.bgm.items = [first, second]
        state.bgm.currentID = current.id
        state.bgm.phase = .playing
        state.bgm.generation = 7
        state.panic.isActive = panicActive
        if panicActive {
            state.panic.snapshot = PanicPlaybackSnapshot(
                currentProgramID: nil,
                wasMediaPlaying: false,
                currentBGMID: current.id,
                wasBGMPlaying: true
            )
        }
        return (state, first, second)
    }

    private func makeViewModel(ports: AdjacentPanicPorts) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(
                recordsOnly: false,
                bgm: ports.bgm,
                bgmTimer: ports.timer
            ),
            environment: .productionPanicOwning(liveAudioFadeDuration: 0)
        )
        let suiteName = "BGMRuntimeAdjacentPanicTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults,
            runtime: runtime
        )
    }

    private func viewModelBGMControlBody(named name: String) throws -> String {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+BGMControls.swift")
        return try XCTUnwrap(source.extractedRuntimeFunctionBody(named: name))
    }

    private func bgmItem(title: String) -> BGMItem {
        BGMItem(
            id: UUID(),
            title: title,
            url: URL(fileURLWithPath: "/tmp/\(UUID().uuidString)-\(title).mp3"),
            category: .warmUp
        )
    }
}

private final class AdjacentPanicPorts {
    let bgm = AdjacentPanicBGMPort()
    let timer = AdjacentPanicTimerPort()

    func reset() {
        bgm.events.removeAll()
        timer.events.removeAll()
    }
}

private final class AdjacentPanicBGMPort: BGMPlaybackPort {
    enum Event: Equatable {
        case prepare(UUID, Int)
        case play(Int)
        case pause(Int)
        case stop(TimeInterval, Int)
    }

    var events: [Event] = []

    func prepare(item: BGMItem, generation: Int) { events.append(.prepare(item.id, generation)) }
    func play(generation: Int) { events.append(.play(generation)) }
    func pause(generation: Int) { events.append(.pause(generation)) }
    func stop(fade: TimeInterval, generation: Int) { events.append(.stop(fade, generation)) }
    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) {}
    func seekToBeginning(generation: Int) {}
    func seek(toProgress progress: Double, generation: Int) {}
    func setPlayMode(_ playMode: BGMPlayMode, generation: Int?) {}
}

private final class AdjacentPanicTimerPort: BGMTimerPort {
    enum Event: Equatable {
        case start(Int)
        case stop(Int)
    }

    var events: [Event] = []

    func start(generation: Int) { events.append(.start(generation)) }
    func stop(generation: Int) { events.append(.stop(generation)) }
}
