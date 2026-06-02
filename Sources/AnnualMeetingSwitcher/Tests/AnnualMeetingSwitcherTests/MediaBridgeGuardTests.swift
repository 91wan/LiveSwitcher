import XCTest
@testable import LiveSwitcher

final class MediaBridgeGuardTests: XCTestCase {
    func testAudioOwnedPlaybackToggleDoesNotMutateMediaStateOrEmitEffects() {
        var state = LiveRuntimeState()
        state.media.loadedURL = URL(fileURLWithPath: "/tmp/video.mp4")
        let originalMedia = state.media

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorToggledMediaPlayback,
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        XCTAssertEqual(mutation.state.media, originalMedia)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testAudioOwnedRestartDoesNotMutateMediaStateOrEmitEffects() {
        let item = ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: URL(fileURLWithPath: "/tmp/video.mp4"))
        var state = LiveRuntimeState()
        state.program.items = [item]
        state.program.currentID = item.id
        state.media.currentTime = 42
        state.media.didPlayToEnd = true
        let originalMedia = state.media

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorRestartedCurrentMedia,
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        XCTAssertEqual(mutation.state.media, originalMedia)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testMediaOwnedModeAllowsMediaEffects() {
        var state = LiveRuntimeState()
        state.media.loadedURL = URL(fileURLWithPath: "/tmp/video.mp4")

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorToggledMediaPlayback,
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        )

        XCTAssertTrue(mutation.effects.contains(.playMedia(generation: 0)))
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .mediaPlaybackChanged)))
    }
}
