import XCTest
@testable import LiveSwitcher

final class ProjectionRuntimeReducerBehaviorTests: XCTestCase {
    func testReducerPreservesStartStopAndFailureBehavior() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true
        var effects: [LiveRuntimeEffect] = []

        ProjectionRuntimeReducer.toggleProjection(
            state: &state,
            effects: &effects,
            canWriteSupport: false,
            now: Date(timeIntervalSince1970: 100)
        )

        XCTAssertTrue(state.projection.isBroadcasting)
        XCTAssertNil(state.projection.safetyNotice)
        XCTAssertEqual(effects, [.startProjection])

        effects.removeAll()
        ProjectionRuntimeReducer.toggleProjection(
            state: &state,
            effects: &effects,
            canWriteSupport: false,
            now: Date(timeIntervalSince1970: 101)
        )

        XCTAssertFalse(state.projection.isBroadcasting)
        XCTAssertNil(state.projection.safetyNotice)
        XCTAssertEqual(effects, [.stopProjection])

        effects.removeAll()
        state.projection.hasExternalDisplay = false
        ProjectionRuntimeReducer.toggleProjection(
            state: &state,
            effects: &effects,
            canWriteSupport: false,
            now: Date(timeIntervalSince1970: 102)
        )

        XCTAssertFalse(state.projection.isBroadcasting)
        XCTAssertFalse(state.projection.hasExternalDisplay)
        XCTAssertEqual(state.projection.safetyNotice, "未检测到外接屏幕，未开始投射")
        XCTAssertTrue(effects.isEmpty)
    }

    func testDisplayLossRecordsTimestampAndStopsOnlyOnce() {
        var state = LiveRuntimeState()
        state.projection.isBroadcasting = true
        state.projection.hasExternalDisplay = true
        var effects: [LiveRuntimeEffect] = []

        ProjectionRuntimeReducer.externalDisplayLost(
            state: &state,
            effects: &effects,
            canWriteSupport: false,
            now: Date(timeIntervalSince1970: 100)
        )

        XCTAssertFalse(state.projection.isBroadcasting)
        XCTAssertFalse(state.projection.hasExternalDisplay)
        XCTAssertEqual(state.projection.safetyNotice, "副屏已断开，投射已停止")
        XCTAssertEqual(state.projection.lastDisplayLostAt, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(effects, [.stopProjection])

        effects.removeAll()
        ProjectionRuntimeReducer.externalDisplayLost(
            state: &state,
            effects: &effects,
            canWriteSupport: false,
            now: Date(timeIntervalSince1970: 101)
        )

        XCTAssertTrue(effects.isEmpty)
        XCTAssertEqual(state.projection.lastDisplayLostAt, Date(timeIntervalSince1970: 100))
    }
}
