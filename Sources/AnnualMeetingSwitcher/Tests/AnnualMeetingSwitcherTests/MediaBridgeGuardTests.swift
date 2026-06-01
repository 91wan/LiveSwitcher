import XCTest
@testable import LiveSwitcher

final class MediaBridgeGuardTests: XCTestCase {
    func testAudioOwnedPlaybackToggleUpdatesMirrorButBlocksMediaEffects() {
        var state = LiveRuntimeState()
        state.media.loadedURL = URL(fileURLWithPath: "/tmp/video.mp4")

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorToggledMediaPlayback,
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        XCTAssertTrue(mutation.state.media.isPlaying)
        XCTAssertEqual(mutation.effects, [.applyAudioRouting(reason: .mediaPlaybackChanged)])
    }

    func testAudioOwnedRestartUpdatesMirrorButBlocksMediaEffects() {
        let item = ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: URL(fileURLWithPath: "/tmp/video.mp4"))
        var state = LiveRuntimeState()
        state.program.items = [item]
        state.program.currentID = item.id
        state.media.currentTime = 42
        state.media.didPlayToEnd = true

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorRestartedCurrentMedia,
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        XCTAssertEqual(mutation.state.media.currentTime, 0)
        XCTAssertTrue(mutation.state.media.isPlaying)
        XCTAssertEqual(mutation.effects, [.applyAudioRouting(reason: .mediaPlaybackChanged)])
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
