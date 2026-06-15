import XCTest
@testable import LiveSwitcher

final class AudioRuntimeTakeoverTests: XCTestCase {
    func testBGMTakeoverRoutesToBGMAndAppliesLimiterReason() {
        let mutation = LiveRuntimeReducer.reduce(
            state: audioState(mediaPlaying: true, bgmPlaying: true),
            action: .operatorChangedBGMTakeover(true),
            environment: .fullRuntimeForTests()
        )

        XCTAssertTrue(mutation.state.audio.isBGMTakeoverActive)
        XCTAssertEqual(mutation.state.audio.effectiveMedia, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(mutation.state.audio.effectiveBGM, 0)
        XCTAssertEqual(mutation.effects, [.applyAudioRouting(reason: .limiterChanged)])
    }
}
