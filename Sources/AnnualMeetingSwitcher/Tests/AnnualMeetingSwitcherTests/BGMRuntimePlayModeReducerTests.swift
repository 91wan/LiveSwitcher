import XCTest
@testable import LiveSwitcher

final class BGMRuntimePlayModeReducerTests: XCTestCase {
    func testSetBGMPlayModeUpdatesRuntimeState() {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.setPlayMode(.sequential, state: &state, effects: &effects)

        XCTAssertEqual(state.bgm.playMode, .sequential)
    }

    func testSetBGMPlayModeEmitsSetPlayModeEffectWhenCurrentBGMExists() {
        let item = bgmItem()
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        state.bgm.currentID = item.id
        state.bgm.generation = 5
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.setPlayMode(.loopOne, state: &state, effects: &effects)

        XCTAssertTrue(effects.contains(.setBGMPlayMode(.loopOne, generation: 5)))
    }

    func testSetBGMPlayModeEmitsNilGenerationWhenNoCurrentBGM() {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.setPlayMode(.sequential, state: &state, effects: &effects)

        XCTAssertTrue(effects.contains(.setBGMPlayMode(.sequential, generation: nil)))
    }

    func testSetBGMPlayModeEmitsSaveBGMPlayMode() {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.setPlayMode(.loopOne, state: &state, effects: &effects)

        XCTAssertTrue(effects.contains(.saveBGMPlayMode(.loopOne)))
    }

    private func bgmItem() -> BGMItem {
        BGMItem(title: "Walk In", url: URL(fileURLWithPath: "/tmp/walk-in.mp3"))
    }
}
