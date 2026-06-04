import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMRuntimeFadePolicyTests: XCTestCase {
    func testLiveRuntimeEnvironmentCarriesLiveAudioFadeDuration() {
        let environment = LiveRuntimeEnvironment.productionPPTOwning(liveAudioFadeDuration: 1.25)

        XCTAssertEqual(environment.liveAudioFadeDuration, 1.25)
        XCTAssertEqual(environment.bridgeMode, .pptOwned)
    }

    func testProductionPPTOwningEnvironmentDefaultsToTwoSecondFade() {
        XCTAssertEqual(LiveRuntimeEnvironment.productionPPTOwning().liveAudioFadeDuration, 2.0)
    }

    func testViewModelSyncsLiveAudioFadeDurationIntoRuntimeBeforeBGMStop() {
        let item = bgmItem(title: "Walk-in")
        let ports = BGMRuntimeFadePolicyPorts()
        let viewModel = makeViewModel(ports: ports)
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)
        ports.reset()

        viewModel.liveAudioFadeDuration = 1.25
        viewModel.toggleBGM(item)

        XCTAssertEqual(ports.bgm.events, [.stop(1.25, 2)])
    }

    func testChangingViewModelLiveAudioFadeDurationAffectsBGMStopEffect() {
        let item = bgmItem(title: "Walk-in")
        let ports = BGMRuntimeFadePolicyPorts()
        let viewModel = makeViewModel(ports: ports)
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)
        ports.reset()

        viewModel.liveAudioFadeDuration = 1.75
        viewModel.toggleBGM(item)

        XCTAssertEqual(ports.bgm.events, [.stop(1.75, 2)])
    }

    func testRuntimeEnvironmentBridgeModeIsPreservedWhenFadeDurationSyncs() {
        let item = bgmItem(title: "Walk-in")
        let ports = BGMRuntimeFadePolicyPorts()
        let viewModel = makeViewModel(ports: ports)
        viewModel.bgmItems = [item]

        viewModel.liveAudioFadeDuration = 1.5
        viewModel.toggleBGM(item)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .bgmOwned)
    }

    private func makeViewModel(ports: BGMRuntimeFadePolicyPorts) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(
                recordsOnly: false,
                bgm: ports.bgm,
                bgmTimer: ports.timer
            ),
            environment: .productionBGMOwning()
        )
        let suiteName = "BGMRuntimeFadePolicyTests.\(UUID().uuidString)"
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

private final class BGMRuntimeFadePolicyPorts {
    let bgm = BGMRuntimeFadePolicyPlaybackPort()
    let timer = BGMRuntimeFadePolicyTimerPort()

    func reset() {
        bgm.events.removeAll()
    }
}

private final class BGMRuntimeFadePolicyPlaybackPort: BGMPlaybackPort {
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

private final class BGMRuntimeFadePolicyTimerPort: BGMTimerPort {
    func start(generation: Int) {}
    func stop(generation: Int) {}
}
