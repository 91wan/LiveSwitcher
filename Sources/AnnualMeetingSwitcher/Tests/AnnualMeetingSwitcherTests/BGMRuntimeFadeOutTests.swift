import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMRuntimeFadeOutTests: XCTestCase {
    func testOperatorStoppedBGMUsesLiveAudioFadeDuration() {
        let item = bgmItem(title: "Walk-in")
        let state = stateWithPlayingBGM(item)

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorStoppedBGM,
            environment: .productionPPTOwning(liveAudioFadeDuration: 2.0)
        )

        XCTAssertEqual(Array(mutation.effects.prefix(3)), [
            .stopBGM(fade: 2.0, generation: state.bgm.generation + 1),
            .stopBGMTimer(generation: state.bgm.generation + 1),
            .applyAudioRouting(reason: .bgmPlaybackChanged)
        ])
    }

    func testOperatorStoppedBGMUsesCustomLiveAudioFadeDuration() {
        let item = bgmItem(title: "Walk-in")
        let state = stateWithPlayingBGM(item)

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorStoppedBGM,
            environment: .productionPPTOwning(liveAudioFadeDuration: 1.25)
        )

        XCTAssertTrue(mutation.effects.contains(.stopBGM(fade: 1.25, generation: state.bgm.generation + 1)))
    }

    func testToggleCurrentPlayingBGMStopsWithConfiguredFadeDuration() {
        let item = bgmItem(title: "Walk-in")
        let ports = BGMRuntimeFadeOutPorts()
        let viewModel = makeViewModel(ports: ports, liveAudioFadeDuration: 1.25)
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)
        ports.reset()

        viewModel.toggleBGM(item)

        XCTAssertEqual(ports.bgm.events, [.stop(1.25, 2)])
    }

    func testRemoveCurrentBGMStopsWithConfiguredFadeDuration() {
        let item = bgmItem(title: "Walk-in")
        let ports = BGMRuntimeFadeOutPorts()
        let viewModel = makeViewModel(ports: ports, liveAudioFadeDuration: 1.5)
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)
        ports.reset()

        viewModel.removeBGMItem(item)

        XCTAssertEqual(ports.bgm.events, [.stop(1.5, 2)])
    }

    func testManualBGMStopDoesNotUseHardcodedHalfSecondFade() {
        let item = bgmItem(title: "Walk-in")
        let state = stateWithPlayingBGM(item)

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorStoppedBGM,
            environment: .productionPPTOwning(liveAudioFadeDuration: 1.25)
        )

        XCTAssertFalse(mutation.effects.contains(.stopBGM(fade: 0.5, generation: state.bgm.generation + 1)))
    }

    func testManualBGMStopEmitsApplyAudioRoutingWithBGMPlaybackChanged() {
        let item = bgmItem(title: "Walk-in")
        let state = stateWithPlayingBGM(item)

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorStoppedBGM,
            environment: .productionPPTOwning(liveAudioFadeDuration: 1.25)
        )

        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .bgmPlaybackChanged)))
    }

    func testManualBGMStopKeepsCurrentTrackSelectedButStopsPlayback() {
        let item = bgmItem(title: "Walk-in")
        let state = stateWithPlayingBGM(item)

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorStoppedBGM,
            environment: .productionPPTOwning(liveAudioFadeDuration: 1.25)
        )

        XCTAssertEqual(mutation.state.bgm.currentID, item.id)
        XCTAssertFalse(mutation.state.bgm.isPlaying)
    }

    private func stateWithPlayingBGM(_ item: BGMItem) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        state.bgm.currentID = item.id
        state.bgm.isPlaying = true
        state.bgm.generation = 4
        return state
    }

    private func makeViewModel(
        ports: BGMRuntimeFadeOutPorts,
        liveAudioFadeDuration: Double
    ) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(
                recordsOnly: false,
                bgm: ports.bgm,
                bgmTimer: ports.timer
            ),
            environment: .productionBGMOwning()
        )
        let suiteName = "BGMRuntimeFadeOutTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults,
            runtime: runtime
        )
        viewModel.liveAudioFadeDuration = liveAudioFadeDuration
        return viewModel
    }

    private func bgmItem(title: String) -> BGMItem {
        BGMItem(title: title, url: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).mp3"))
    }
}

private final class BGMRuntimeFadeOutPorts {
    let bgm = BGMRuntimeFadeOutPlaybackPort()
    let timer = BGMRuntimeFadeOutTimerPort()

    func reset() {
        bgm.events.removeAll()
        timer.events.removeAll()
    }
}

private final class BGMRuntimeFadeOutPlaybackPort: BGMPlaybackPort {
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

private final class BGMRuntimeFadeOutTimerPort: BGMTimerPort {
    enum Event: Equatable {
        case start(Int)
        case stop(Int)
    }

    var events: [Event] = []

    func start(generation: Int) { events.append(.start(generation)) }
    func stop(generation: Int) { events.append(.stop(generation)) }
}
