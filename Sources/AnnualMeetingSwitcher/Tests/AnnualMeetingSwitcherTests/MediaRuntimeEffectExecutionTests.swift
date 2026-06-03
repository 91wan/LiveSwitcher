import XCTest
@testable import LiveSwitcher

@MainActor
final class MediaRuntimeEffectExecutionTests: XCTestCase {
    func testLoadMediaEffectCallsMediaPort() {
        let media = MediaRuntimeEffectPortSpy()
        let runner = runner(media: media)
        let state = state(generation: 3)
        let url = URL(fileURLWithPath: "/tmp/load.mp4")

        runner.run([.loadMedia(url, generation: 3)], currentState: { state }, dispatch: { _ in })

        XCTAssertEqual(media.events, [.load(url, generation: 3)])
    }

    func testPlayMediaEffectCallsMediaPort() {
        let media = MediaRuntimeEffectPortSpy()
        let runner = runner(media: media)
        let state = state(generation: 3)

        runner.run([.playMedia(generation: 3)], currentState: { state }, dispatch: { _ in })

        XCTAssertEqual(media.events, [.play(generation: 3)])
    }

    func testPauseMediaEffectCallsMediaPort() {
        let media = MediaRuntimeEffectPortSpy()
        let runner = runner(media: media)
        let state = state(generation: 3)

        runner.run([.pauseMedia(generation: 3)], currentState: { state }, dispatch: { _ in })

        XCTAssertEqual(media.events, [.pause(generation: 3)])
    }

    func testRestartMediaEffectCallsMediaPort() {
        let media = MediaRuntimeEffectPortSpy()
        let runner = runner(media: media)
        let state = state(generation: 3)

        runner.run([.restartMedia(generation: 3)], currentState: { state }, dispatch: { _ in })

        XCTAssertEqual(media.events, [.restart(generation: 3)])
    }

    func testStopMediaEffectCallsMediaPort() {
        let media = MediaRuntimeEffectPortSpy()
        let runner = runner(media: media)
        let state = state(generation: 3)

        runner.run([.stopMedia(generation: 3)], currentState: { state }, dispatch: { _ in })

        XCTAssertEqual(media.events, [.stop(generation: 3)])
    }

    func testSetMediaVolumeEffectCallsMediaPort() {
        let media = MediaRuntimeEffectPortSpy()
        let runner = runner(media: media)
        let state = state(generation: 3)

        runner.run([.setMediaVolume(0.25, fade: 0.4, generation: 3)], currentState: { state }, dispatch: { _ in })

        XCTAssertEqual(media.events, [.setVolume(0.25, fade: 0.4, generation: 3)])
    }

    private func runner(media: MediaRuntimeEffectPortSpy) -> LiveRuntimeEffectRunner {
        LiveRuntimeEffectRunner(recordsOnly: false, media: media)
    }

    private func state(generation: Int) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.media.generation = generation
        return state
    }
}

private enum MediaRuntimeEffectEvent: Equatable {
    case load(URL, generation: Int)
    case play(generation: Int)
    case pause(generation: Int)
    case restart(generation: Int)
    case stop(generation: Int)
    case setVolume(Float, fade: TimeInterval, generation: Int)
}

private final class MediaRuntimeEffectPortSpy: MediaPlaybackPort {
    private(set) var events: [MediaRuntimeEffectEvent] = []

    func load(url: URL, generation: Int) {
        events.append(.load(url, generation: generation))
    }

    func play(generation: Int) {
        events.append(.play(generation: generation))
    }

    func pause(generation: Int) {
        events.append(.pause(generation: generation))
    }

    func restart(generation: Int) {
        events.append(.restart(generation: generation))
    }

    func stop(generation: Int) {
        events.append(.stop(generation: generation))
    }

    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) {
        events.append(.setVolume(volume, fade: fade, generation: generation))
    }
}
