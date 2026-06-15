import XCTest
@testable import LiveSwitcher

final class BGMRuntimeProgressReducerTests: XCTestCase {
    func testProgressUpdatedStoresTimeAndDuration() {
        var state = currentBGMState(generation: 4)

        BGMRuntimeReducer.progressUpdated(time: 12, duration: 30, generation: 4, state: &state)

        XCTAssertEqual(state.bgm.currentTime, 12)
        XCTAssertEqual(state.bgm.duration, 30)
    }

    func testProgressUpdatedClampsNegativeTimeToZero() {
        var state = currentBGMState(generation: 4)

        BGMRuntimeReducer.progressUpdated(time: -5, duration: 30, generation: 4, state: &state)

        XCTAssertEqual(state.bgm.currentTime, 0)
    }

    func testProgressUpdatedComputesProgressFromDuration() {
        var state = currentBGMState(generation: 4)

        BGMRuntimeReducer.progressUpdated(time: 15, duration: 30, generation: 4, state: &state)

        XCTAssertEqual(state.bgm.progress, 0.5, accuracy: 0.0001)
    }

    func testProgressUpdatedClampsProgressAtOne() {
        var state = currentBGMState(generation: 4)

        BGMRuntimeReducer.progressUpdated(time: 40, duration: 30, generation: 4, state: &state)

        XCTAssertEqual(state.bgm.progress, 1)
    }

    func testProgressUpdatedIgnoresStaleGeneration() {
        var state = currentBGMState(generation: 4)

        BGMRuntimeReducer.progressUpdated(time: 12, duration: 30, generation: 3, state: &state)

        XCTAssertEqual(state.bgm.currentTime, 0)
        XCTAssertNil(state.bgm.duration)
        XCTAssertEqual(state.bgm.progress, 0)
    }

    private func currentBGMState(generation: Int) -> LiveRuntimeState {
        let item = BGMItem(title: "Walk In", url: URL(fileURLWithPath: "/tmp/walk-in.mp3"))
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        state.bgm.currentID = item.id
        state.bgm.generation = generation
        return state
    }
}
