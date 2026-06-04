import XCTest
@testable import LiveSwitcher

final class BGMRuntimeEffectExecutionTests: XCTestCase {
    func testPrepareBGMEffectCallsBGMPort() {
        let item = BGMItem(title: "Walk-in", url: URL(fileURLWithPath: "/tmp/walk-in.mp3"))
        let port = runBGMEffects([.prepareBGM(item, generation: 9)], generation: 9)

        XCTAssertEqual(port.calls, ["prepare:9:Walk-in"])
    }

    func testPlayBGMEffectCallsBGMPort() {
        let port = runBGMEffects([.playBGM(generation: 9)], generation: 9)

        XCTAssertEqual(port.calls, ["play:9"])
    }

    func testPauseBGMEffectCallsBGMPort() {
        let port = runBGMEffects([.pauseBGM(generation: 9)], generation: 9)

        XCTAssertEqual(port.calls, ["pause:9"])
    }

    func testStopBGMEffectCallsBGMPort() {
        let port = runBGMEffects([.stopBGM(fade: 0.4, generation: 9)], generation: 9)

        XCTAssertEqual(port.calls, ["stop:9:0.4"])
    }

    func testStopBGMEffectPreservesPositiveFadeForPort() {
        let port = runBGMEffects([.stopBGM(fade: 1.25, generation: 9)], generation: 9)

        XCTAssertEqual(port.calls, ["stop:9:1.25"])
    }

    func testSetBGMVolumeEffectCallsBGMPort() {
        let port = runBGMEffects([.setBGMVolume(0.25, fade: 0.2, generation: 9)], generation: 9)

        XCTAssertEqual(port.calls, ["volume:9:0.25:0.2"])
    }

    func testSeekBGMToBeginningEffectCallsBGMPort() {
        let port = runBGMEffects([.seekBGMToBeginning(generation: 9)], generation: 9)

        XCTAssertEqual(port.calls, ["seekToBeginning:9"])
    }

    func testSeekBGMToProgressEffectCallsBGMPort() {
        let port = runBGMEffects([.seekBGMToProgress(0.25, generation: 9)], generation: 9)

        XCTAssertEqual(port.calls, ["seekToProgress:9:0.25"])
    }

    func testSetBGMPlayModeEffectCallsBGMPort() {
        let port = runBGMEffects([.setBGMPlayMode(.loopOne, generation: 9)], generation: 9)

        XCTAssertEqual(port.calls, ["setPlayMode:9:单曲循环"])
    }

    func testStartBGMTimerEffectCallsTimerPort() {
        let timer = runBGMTimerEffects([.startBGMTimer(generation: 9)], generation: 9)

        XCTAssertEqual(timer.calls, ["start:9"])
    }

    func testStopBGMTimerEffectCallsTimerPort() {
        let timer = runBGMTimerEffects([.stopBGMTimer(generation: 9)], generation: 9)

        XCTAssertEqual(timer.calls, ["stop:9"])
    }

    func testStalePrepareBGMEffectDoesNotCallBGMPort() {
        let item = BGMItem(title: "Walk-in", url: URL(fileURLWithPath: "/tmp/walk-in.mp3"))
        let port = runBGMEffects([.prepareBGM(item, generation: 8)], generation: 9)

        XCTAssertEqual(port.calls, [])
    }

    func testStaleSetBGMPlayModeEffectDoesNotCallBGMPortWhenGenerationProvided() {
        let port = runBGMEffects([.setBGMPlayMode(.loopOne, generation: 8)], generation: 9)

        XCTAssertEqual(port.calls, [])
    }

    func testNilGenerationSetBGMPlayModeStillCallsPort() {
        let port = runBGMEffects([.setBGMPlayMode(.sequential, generation: nil)], generation: 9)

        XCTAssertEqual(port.calls, ["setPlayMode:nil:顺序播放"])
    }

    func testBGMSeekAndLoopEffectsExecuteThroughBGMPort() {
        let port = BGMRuntimeEffectExecutionPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, bgm: port)
        var state = LiveRuntimeState()
        state.bgm.generation = 9

        runner.run(
            [
                .seekBGMToBeginning(generation: 9),
                .seekBGMToProgress(0.25, generation: 9),
                .setBGMPlayMode(.loopOne, generation: 9)
            ],
            currentState: { state },
            dispatch: { _ in }
        )

        XCTAssertEqual(port.calls, [
            "seekToBeginning:9",
            "seekToProgress:9:0.25",
            "setPlayMode:9:单曲循环"
        ])
    }

    func testStaleBGMSeekAndLoopEffectsAreIgnored() {
        let port = BGMRuntimeEffectExecutionPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, bgm: port)
        var state = LiveRuntimeState()
        state.bgm.generation = 10

        runner.run(
            [
                .seekBGMToBeginning(generation: 9),
                .seekBGMToProgress(0.25, generation: 9),
                .setBGMPlayMode(.loopOne, generation: 9)
            ],
            currentState: { state },
            dispatch: { _ in }
        )

        XCTAssertEqual(port.calls, [])
    }

    func testLoopModeEffectWithoutCurrentGenerationStillUpdatesPort() {
        let port = BGMRuntimeEffectExecutionPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, bgm: port)

        runner.run(
            [.setBGMPlayMode(.sequential, generation: nil)],
            currentState: { LiveRuntimeState() },
            dispatch: { _ in }
        )

        XCTAssertEqual(port.calls, ["setPlayMode:nil:顺序播放"])
    }

    private func runBGMEffects(_ effects: [LiveRuntimeEffect], generation: Int) -> BGMRuntimeEffectExecutionPortSpy {
        let port = BGMRuntimeEffectExecutionPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, bgm: port)
        var state = LiveRuntimeState()
        state.bgm.generation = generation

        runner.run(effects, currentState: { state }, dispatch: { _ in })

        return port
    }

    private func runBGMTimerEffects(_ effects: [LiveRuntimeEffect], generation: Int) -> BGMRuntimeEffectExecutionTimerPortSpy {
        let timer = BGMRuntimeEffectExecutionTimerPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, bgmTimer: timer)
        var state = LiveRuntimeState()
        state.bgm.generation = generation

        runner.run(effects, currentState: { state }, dispatch: { _ in })

        return timer
    }
}

private final class BGMRuntimeEffectExecutionPortSpy: BGMPlaybackPort {
    private(set) var calls: [String] = []

    func prepare(item: BGMItem, generation: Int) {
        calls.append("prepare:\(generation):\(item.title)")
    }
    func play(generation: Int) {
        calls.append("play:\(generation)")
    }
    func pause(generation: Int) {
        calls.append("pause:\(generation)")
    }
    func stop(fade: TimeInterval, generation: Int) {
        calls.append("stop:\(generation):\(fade)")
    }
    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) {
        calls.append("volume:\(generation):\(volume):\(fade)")
    }
    func seekToBeginning(generation: Int) {
        calls.append("seekToBeginning:\(generation)")
    }
    func seek(toProgress progress: Double, generation: Int) {
        calls.append("seekToProgress:\(generation):\(progress)")
    }
    func setPlayMode(_ playMode: BGMPlayMode, generation: Int?) {
        calls.append("setPlayMode:\(generation.map(String.init) ?? "nil"):\(playMode.rawValue)")
    }
}

private final class BGMRuntimeEffectExecutionTimerPortSpy: BGMTimerPort {
    private(set) var calls: [String] = []

    func start(generation: Int) {
        calls.append("start:\(generation)")
    }

    func stop(generation: Int) {
        calls.append("stop:\(generation)")
    }
}
