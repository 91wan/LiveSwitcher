import XCTest
@testable import LiveSwitcher

@MainActor
final class MediaRuntimeGenerationTests: XCTestCase {
    func testStaleLoadMediaEffectIsIgnored() {
        assertStaleEffectIgnored(.loadMedia(URL(fileURLWithPath: "/tmp/stale.mp4"), generation: 4))
    }

    func testStalePlayMediaEffectIsIgnored() {
        assertStaleEffectIgnored(.playMedia(generation: 4))
    }

    func testStalePauseMediaEffectIsIgnored() {
        assertStaleEffectIgnored(.pauseMedia(generation: 4))
    }

    func testStaleRestartMediaEffectIsIgnored() {
        assertStaleEffectIgnored(.restartMedia(generation: 4))
    }

    func testStaleStopMediaEffectIsIgnored() {
        assertStaleEffectIgnored(.stopMedia(generation: 4))
    }

    func testStaleSeekToStartEffectIsIgnored() {
        assertStaleEffectIgnored(.seekMediaToStart(generation: 4))
    }

    func testStaleSeekToEndEffectIsIgnored() {
        assertStaleEffectIgnored(.seekMediaToEnd(generation: 4))
    }

    func testStaleSeekToProgressEffectIsIgnored() {
        assertStaleEffectIgnored(.seekMediaToProgress(0.4, generation: 4))
    }

    func testCurrentGenerationMediaEffectExecutes() {
        let media = MediaRuntimeGenerationPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, media: media)
        let state = state(generation: 5)

        runner.run([.playMedia(generation: 5)], currentState: { state }, dispatch: { _ in })

        XCTAssertEqual(media.callCount, 1)
    }

    private func assertStaleEffectIgnored(_ effect: LiveRuntimeEffect) {
        let media = MediaRuntimeGenerationPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, media: media)
        let state = state(generation: 5)

        runner.run([effect], currentState: { state }, dispatch: { _ in })

        XCTAssertEqual(media.callCount, 0)
    }

    private func state(generation: Int) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.media.generation = generation
        return state
    }
}

private final class MediaRuntimeGenerationPortSpy: MediaPlaybackPort {
    private(set) var callCount = 0

    func load(url: URL, generation: Int) { callCount += 1 }
    func play(generation: Int) { callCount += 1 }
    func pause(generation: Int) { callCount += 1 }
    func restart(generation: Int) { callCount += 1 }
    func stop(generation: Int) { callCount += 1 }
    func seekToStart(generation: Int) { callCount += 1 }
    func seekToEnd(generation: Int) { callCount += 1 }
    func seek(toProgress progress: Double, generation: Int) { callCount += 1 }
    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) { callCount += 1 }
}
