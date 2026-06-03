import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMRuntimeGenerationTests: XCTestCase {
    func testStalePrepareBGMEffectIsIgnored() {
        assertStaleBGMEffectIgnored(.prepareBGM(bgmItem(), generation: 4))
    }

    func testStalePlayBGMEffectIsIgnored() {
        assertStaleBGMEffectIgnored(.playBGM(generation: 4))
    }

    func testStalePauseBGMEffectIsIgnored() {
        assertStaleBGMEffectIgnored(.pauseBGM(generation: 4))
    }

    func testStaleStopBGMEffectIsIgnored() {
        assertStaleBGMEffectIgnored(.stopBGM(fade: 0.5, generation: 4))
    }

    func testStaleSetBGMVolumeEffectIsIgnored() {
        assertStaleBGMEffectIgnored(.setBGMVolume(0.4, fade: 0.2, generation: 4))
    }

    func testStaleStartBGMTimerEffectIsIgnored() {
        assertStaleBGMTimerEffectIgnored(.startBGMTimer(generation: 4))
    }

    func testStaleStopBGMTimerEffectIsIgnored() {
        assertStaleBGMTimerEffectIgnored(.stopBGMTimer(generation: 4))
    }

    func testCurrentGenerationBGMEffectExecutes() {
        let bgm = BGMRuntimeGenerationPlaybackPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, bgm: bgm)
        let state = state(generation: 5)

        runner.run([.playBGM(generation: 5)], currentState: { state }, dispatch: { _ in })

        XCTAssertEqual(bgm.callCount, 1)
    }

    private func assertStaleBGMEffectIgnored(_ effect: LiveRuntimeEffect) {
        let bgm = BGMRuntimeGenerationPlaybackPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, bgm: bgm)
        let state = state(generation: 5)

        runner.run([effect], currentState: { state }, dispatch: { _ in })

        XCTAssertEqual(bgm.callCount, 0)
    }

    private func assertStaleBGMTimerEffectIgnored(_ effect: LiveRuntimeEffect) {
        let timer = BGMRuntimeGenerationTimerPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, bgmTimer: timer)
        let state = state(generation: 5)

        runner.run([effect], currentState: { state }, dispatch: { _ in })

        XCTAssertEqual(timer.callCount, 0)
    }

    private func state(generation: Int) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.bgm.generation = generation
        return state
    }

    private func bgmItem() -> BGMItem {
        BGMItem(title: "Walk-in", url: URL(fileURLWithPath: "/tmp/walk-in.mp3"))
    }
}

private final class BGMRuntimeGenerationPlaybackPortSpy: BGMPlaybackPort {
    private(set) var callCount = 0

    func prepare(item: BGMItem, generation: Int) { callCount += 1 }
    func play(generation: Int) { callCount += 1 }
    func pause(generation: Int) { callCount += 1 }
    func stop(fade: TimeInterval, generation: Int) { callCount += 1 }
    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) { callCount += 1 }
}

private final class BGMRuntimeGenerationTimerPortSpy: BGMTimerPort {
    private(set) var callCount = 0

    func start(generation: Int) { callCount += 1 }
    func stop(generation: Int) { callCount += 1 }
}
