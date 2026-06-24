import XCTest
@testable import LiveSwitcher

@MainActor
final class LiveRuntimeBGMBridgeTests: XCTestCase {
    func testBGMSelectionProducesPlaybackTimerAndRoutingEffects() {
        let item = bgmItem(title: "Walk-in")
        var state = LiveRuntimeState()
        state.bgm.items = [item]

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedBGM(item.id),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertEqual(mutation.state.bgm.currentID, item.id)
        XCTAssertTrue(mutation.state.bgm.isPlaying)
        XCTAssertEqual(mutation.state.bgm.progress, 0)
        XCTAssertTrue(mutation.effects.contains(.prepareBGM(item, generation: state.bgm.generation + 1)))
        XCTAssertTrue(mutation.effects.contains(.playBGM(generation: state.bgm.generation + 1)))
        XCTAssertTrue(mutation.effects.contains(.startBGMTimer(generation: state.bgm.generation + 1)))
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .bgmPlaybackChanged)))
    }

    func testBGMStopProducesFadeTimerAndRoutingEffects() {
        let item = bgmItem(title: "Stop")
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        state.bgm.currentID = item.id
        state.bgm.phase = .playing

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorStoppedBGM,
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertFalse(mutation.state.bgm.isPlaying)
        XCTAssertTrue(
            mutation.effects.contains(
                .stopBGM(fade: AudioRoutingDefaults.liveAudioFadeDuration, generation: state.bgm.generation + 1)
            )
        )
        XCTAssertTrue(mutation.effects.contains(.stopBGMTimer(generation: state.bgm.generation + 1)))
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .bgmPlaybackChanged)))
    }

    func testBGMCallbacksIgnoreStaleGenerationAndRouteCurrentGeneration() {
        var state = LiveRuntimeState()
        state.bgm.generation = 6
        state.bgm.phase = .playing

        let stale = LiveRuntimeReducer.reduce(
            state: state,
            action: .bgmPlaybackChanged(isPlaying: false, generation: 5),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )
        let current = LiveRuntimeReducer.reduce(
            state: state,
            action: .bgmPlaybackChanged(isPlaying: false, generation: 6),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertTrue(stale.state.bgm.isPlaying)
        XCTAssertTrue(stale.effects.isEmpty)
        XCTAssertFalse(current.state.bgm.isPlaying)
        XCTAssertTrue(current.effects.contains(.applyAudioRouting(reason: .bgmPlaybackChanged)))
    }

    func testBGMProgressCallbackIgnoresStaleGeneration() {
        var state = LiveRuntimeState()
        state.bgm.generation = 3

        let stale = LiveRuntimeReducer.reduce(
            state: state,
            action: .bgmProgressUpdated(time: 9, duration: 10, generation: 2),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )
        let current = LiveRuntimeReducer.reduce(
            state: state,
            action: .bgmProgressUpdated(time: 9, duration: 10, generation: 3),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertEqual(stale.state.bgm.currentTime, 0)
        XCTAssertEqual(stale.state.bgm.progress, 0)
        XCTAssertEqual(current.state.bgm.currentTime, 9)
        XCTAssertEqual(current.state.bgm.progress, 0.9, accuracy: 0.0001)
    }

    func testRuntimeBGMPlayModeSelectionUpdatesRuntimeStateAndRequestsPersistence() {
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorSelectedBGMPlayMode(.sequential),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertEqual(mutation.state.bgm.playMode, .sequential)
        XCTAssertTrue(mutation.effects.contains(.saveBGMPlayMode(.sequential)))
    }

    func testRuntimeLoopOneEndRestartsSameTrackWithNewGeneration() {
        let item = bgmItem(title: "Loop One")
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        state.bgm.currentID = item.id
        state.bgm.phase = .playing
        state.bgm.playMode = .loopOne
        state.bgm.generation = 4

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .bgmReachedEnd(generation: 4),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertEqual(mutation.state.bgm.currentID, item.id)
        XCTAssertTrue(mutation.state.bgm.isPlaying)
        XCTAssertEqual(mutation.state.bgm.generation, 5)
        XCTAssertEqual(mutation.state.bgm.progress, 0)
        XCTAssertTrue(mutation.effects.contains(.prepareBGM(item, generation: 5)))
        XCTAssertTrue(mutation.effects.contains(.playBGM(generation: 5)))
        XCTAssertTrue(mutation.effects.contains(.startBGMTimer(generation: 5)))
    }

    func testRuntimeLoopAllEndAdvancesToNextTrack() {
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        var state = LiveRuntimeState()
        state.bgm.items = [first, second]
        state.bgm.currentID = first.id
        state.bgm.phase = .playing
        state.bgm.playMode = .loopAll
        state.bgm.generation = 7

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .bgmReachedEnd(generation: 7),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertEqual(mutation.state.bgm.currentID, second.id)
        XCTAssertTrue(mutation.state.bgm.isPlaying)
        XCTAssertEqual(mutation.state.bgm.generation, 8)
        XCTAssertTrue(mutation.effects.contains(.prepareBGM(second, generation: 8)))
        XCTAssertTrue(mutation.effects.contains(.playBGM(generation: 8)))
    }

    func testRuntimeNextPreviousStayInsideCurrentCategory() {
        let warmUp = bgmItem(title: "Warm A", category: .warmUp)
        let ceremony = bgmItem(title: "Ceremony", category: .entrance)
        let warmUpNext = bgmItem(title: "Warm B", category: .warmUp)
        var state = LiveRuntimeState()
        state.bgm.items = [warmUp, ceremony, warmUpNext]
        state.bgm.currentID = warmUp.id
        state.bgm.phase = .playing
        state.bgm.generation = 2

        let next = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedNextBGM,
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )
        let previous = LiveRuntimeReducer.reduce(
            state: next.state,
            action: .operatorSelectedPreviousBGM,
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertEqual(next.state.bgm.currentID, warmUpNext.id)
        XCTAssertTrue(next.effects.contains(.prepareBGM(warmUpNext, generation: 3)))
        XCTAssertEqual(previous.state.bgm.currentID, warmUp.id)
        XCTAssertTrue(previous.effects.contains(.prepareBGM(warmUp, generation: 4)))
    }

    func testRuntimeLoopAllEndAdvancesInsideCurrentCategory() {
        let warmUp = bgmItem(title: "Warm A", category: .warmUp)
        let ceremony = bgmItem(title: "Ceremony", category: .entrance)
        let warmUpNext = bgmItem(title: "Warm B", category: .warmUp)
        var state = LiveRuntimeState()
        state.bgm.items = [warmUp, ceremony, warmUpNext]
        state.bgm.currentID = warmUp.id
        state.bgm.phase = .playing
        state.bgm.playMode = .loopAll
        state.bgm.generation = 7

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .bgmReachedEnd(generation: 7),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertEqual(mutation.state.bgm.currentID, warmUpNext.id)
        XCTAssertTrue(mutation.effects.contains(.prepareBGM(warmUpNext, generation: 8)))
    }

    func testRuntimeFinishedAndFailedBGMReleasePlaybackPort() {
        let item = bgmItem(title: "Tail")
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        state.bgm.currentID = item.id
        state.bgm.phase = .playing
        state.bgm.playMode = .sequential
        state.bgm.generation = 4

        let finished = LiveRuntimeReducer.reduce(
            state: state,
            action: .bgmReachedEnd(generation: 4),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )
        let failed = LiveRuntimeReducer.reduce(
            state: state,
            action: .bgmFailed(reason: "playbackFailed", generation: 4),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertFalse(finished.state.bgm.isPlaying)
        XCTAssertTrue(finished.effects.contains(.stopBGM(fade: 0, generation: 5)))
        XCTAssertTrue(finished.effects.contains(.stopBGMTimer(generation: 5)))
        XCTAssertFalse(failed.state.bgm.isPlaying)
        XCTAssertTrue(failed.effects.contains(.stopBGM(fade: 0, generation: 5)))
        XCTAssertTrue(failed.effects.contains(.stopBGMTimer(generation: 5)))
    }

    func testRuntimeSequentialEndStopsAtLastTrack() {
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        var state = LiveRuntimeState()
        state.bgm.items = [first, second]
        state.bgm.currentID = second.id
        state.bgm.phase = .playing
        state.bgm.playMode = .sequential
        state.bgm.generation = 9

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .bgmReachedEnd(generation: 9),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertEqual(mutation.state.bgm.currentID, second.id)
        XCTAssertFalse(mutation.state.bgm.isPlaying)
        XCTAssertEqual(mutation.state.bgm.generation, 10)
        XCTAssertTrue(mutation.effects.contains(.stopBGMTimer(generation: 10)))
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .bgmPlaybackChanged)))
    }

    func testViewModelBGMSelectionDispatchesRuntimeAction() throws {
        let viewModel = makeViewModel()
        let item = try temporaryBGMItem(title: "Select")
        viewModel.bgmItems = [item]

        viewModel.toggleBGM(item)

        XCTAssertEqual(viewModel.runtime.state.bgm.currentID, item.id)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedBGM" })
    }

    func testViewModelBGMCurrentTrackToggleDispatchesRuntimePauseResumeAction() throws {
        let viewModel = makeViewModel()
        viewModel.liveAudioFadeDuration = 0
        let item = try temporaryBGMItem(title: "Stop")
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)

        viewModel.toggleBGM(item)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorToggledCurrentBGMPlayback" })
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "operatorStoppedBGM" })
    }

    func testViewModelBGMNextPreviousAndEndDispatchRuntimeActions() throws {
        let viewModel = makeViewModel()
        let first = try temporaryBGMItem(title: "First")
        let second = try temporaryBGMItem(title: "Second")
        viewModel.bgmItems = [first, second]
        viewModel.toggleBGM(first)

        viewModel.playNextBGM()
        viewModel.playPreviousBGM()
        viewModel.bgmDidFinish()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedNextBGM" })
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedPreviousBGM" })
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "bgmReachedEnd" })
    }

    func testViewModelBGMFailureAndProgressDispatchRuntimeCallbacks() throws {
        let viewModel = makeViewModel()
        let item = try temporaryBGMItem(title: "Failure")
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)

        viewModel.bgmProgressStore.update(currentTime: 2, duration: 10)
        viewModel.dispatchRuntimeBGMProgressCallback(time: 2, duration: 10)
        viewModel.bgmDidFail()

        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "bgmProgressUpdated" })
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "bgmFailed" })
    }

    func testViewModelLoopModeToggleDispatchesRuntimeAction() {
        let viewModel = makeViewModel()

        viewModel.toggleLoopMode()

        XCTAssertEqual(viewModel.runtime.state.bgm.playMode, .loopOne)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedBGMPlayMode" })
    }

    func testViewModelLoopModeToggleRoutesPersistenceThroughRuntimePort() {
        let suiteName = "LiveRuntimeBGMBridgeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let persistence = PersistencePortSpy()
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, persistence: persistence),
            environment: .productionBGMOwning()
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults,
            runtime: runtime
        )

        viewModel.toggleLoopMode()

        XCTAssertEqual(runtime.state.bgm.playMode, .loopOne)
        XCTAssertEqual(persistence.saveCount, 1)
        XCTAssertEqual(persistence.savedBGMPlayModes, [.loopOne])
        XCTAssertNil(defaults.string(forKey: "bgmPlayMode"))
    }

    private func bgmItem(title: String, category: BGMCategory = .warmUp) -> BGMItem {
        BGMItem(title: title, url: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).mp3"), category: category)
    }

    private func temporaryBGMItem(title: String) throws -> BGMItem {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp3")
        try Data("not-a-decodable-audio-fixture".utf8).write(to: url)
        return BGMItem(title: title, url: url)
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "LiveRuntimeBGMBridgeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
    }
}

private final class PersistencePortSpy: PersistencePort {
    private(set) var saveCount = 0
    private(set) var savedBGMPlayModes: [BGMPlayMode] = []

    func save() {
        saveCount += 1
    }

    func saveConsoleMode(_ mode: ConsoleMode) {}
    func saveThemeOverride(_ theme: ThemeOverride) {}
    func saveAudioStrategy(_ strategy: AudioStrategy) {}
    func saveSpeakerMode(_ isEnabled: Bool) {}

    func saveBGMPlayMode(_ playMode: BGMPlayMode) {
        saveCount += 1
        savedBGMPlayModes.append(playMode)
    }

    func saveAutoPlayNextVideoOnEnd(_ isEnabled: Bool) {}
    func saveAutoAdvanceAtScheduledTime(_ isEnabled: Bool) {}
    func saveShowAgendaTimeline(_ isEnabled: Bool) {}
    func saveCornerLogoPosition(_ position: CornerLogoPosition) {}
}
