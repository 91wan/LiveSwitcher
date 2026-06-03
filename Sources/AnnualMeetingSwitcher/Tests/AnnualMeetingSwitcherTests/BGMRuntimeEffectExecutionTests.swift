import XCTest
@testable import LiveSwitcher

final class BGMRuntimeEffectExecutionTests: XCTestCase {
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
}

private final class BGMRuntimeEffectExecutionPortSpy: BGMPlaybackPort {
    private(set) var calls: [String] = []

    func prepare(item: BGMItem, generation: Int) {}
    func play(generation: Int) {}
    func pause(generation: Int) {}
    func stop(fade: TimeInterval, generation: Int) {}
    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) {}
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
