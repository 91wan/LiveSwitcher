import XCTest
@testable import LiveSwitcher

final class BGMBridgeGuardTests: XCTestCase {
    func testAudioOwnedBGMSelectionDoesNotMutateBGMStateOrEmitEffects() {
        let item = bgmItem(title: "Walk-in")
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        let originalBGM = state.bgm

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedBGM(item.id),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        XCTAssertEqual(mutation.state.bgm, originalBGM)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testAudioOwnedBGMStopDoesNotMutateBGMStateOrEmitEffects() {
        let item = bgmItem(title: "Stop")
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        state.bgm.currentID = item.id
        state.bgm.phase = .playing
        let originalBGM = state.bgm

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorStoppedBGM,
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        XCTAssertEqual(mutation.state.bgm, originalBGM)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testBGMOwningModeAllowsBGMAndTimerEffects() {
        let item = bgmItem(title: "Walk-in")
        var state = LiveRuntimeState()
        state.bgm.items = [item]

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedBGM(item.id),
            environment: LiveRuntimeEnvironment(bridgeMode: .bgmOwned)
        )

        XCTAssertTrue(mutation.effects.contains(.prepareBGM(item, generation: 1)))
        XCTAssertTrue(mutation.effects.contains(.playBGM(generation: 1)))
        XCTAssertTrue(mutation.effects.contains(.startBGMTimer(generation: 1)))
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .bgmPlaybackChanged)))
    }

    private func bgmItem(title: String) -> BGMItem {
        BGMItem(title: title, url: URL(fileURLWithPath: "/tmp/\(title).mp3"))
    }
}
