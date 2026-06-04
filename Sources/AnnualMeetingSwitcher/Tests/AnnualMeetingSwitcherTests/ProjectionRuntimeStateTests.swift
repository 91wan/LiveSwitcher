import XCTest
@testable import LiveSwitcher

final class ProjectionRuntimeStateTests: XCTestCase {
    func testProjectionStartWithExternalDisplaySetsBroadcastingAndStartsProjection() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true

        let mutation = reduce(state, .operatorToggledProjection)

        XCTAssertTrue(mutation.state.projection.isBroadcasting)
        XCTAssertNil(mutation.state.projection.safetyNotice)
        XCTAssertEqual(mutation.effects, [.startProjection])
    }

    func testProjectionStopWhenBroadcastingStopsProjection() {
        var state = LiveRuntimeState()
        state.projection.isBroadcasting = true
        state.projection.hasExternalDisplay = true

        let mutation = reduce(state, .operatorToggledProjection)

        XCTAssertFalse(mutation.state.projection.isBroadcasting)
        XCTAssertNil(mutation.state.projection.safetyNotice)
        XCTAssertEqual(mutation.effects, [.stopProjection])
    }

    func testProjectionStartWithoutExternalDisplaySetsSafetyNoticeAndNoEffect() {
        let mutation = reduce(LiveRuntimeState(), .operatorToggledProjection)

        XCTAssertFalse(mutation.state.projection.isBroadcasting)
        XCTAssertFalse(mutation.state.projection.hasExternalDisplay)
        XCTAssertEqual(mutation.state.projection.safetyNotice, "未检测到外接屏幕，未开始投射")
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testProjectionStartFailureNoTargetScreenSetsSafetyNoticeAndNoEffect() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true

        let mutation = reduce(state, .projectionStartFailed(reason: .noTargetScreen))

        XCTAssertFalse(mutation.state.projection.isBroadcasting)
        XCTAssertFalse(mutation.state.projection.hasExternalDisplay)
        XCTAssertEqual(mutation.state.projection.safetyNotice, "未检测到外接屏幕，未开始投射")
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testProjectionStartFailureDoesNotWriteReducerSupportInProjectionOwnedMode() {
        let mutation = reduce(LiveRuntimeState(), .projectionStartFailed(reason: .externalDisplayUnavailable))

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testProjectionExternalDisplayLostStopsBroadcasting() {
        var state = LiveRuntimeState()
        state.projection.isBroadcasting = true
        state.projection.hasExternalDisplay = true

        let mutation = reduce(state, .projectionExternalDisplayLost)

        XCTAssertFalse(mutation.state.projection.isBroadcasting)
        XCTAssertFalse(mutation.state.projection.hasExternalDisplay)
        XCTAssertEqual(mutation.state.projection.safetyNotice, "副屏已断开，投射已停止")
        XCTAssertEqual(mutation.state.projection.lastDisplayLostAt, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(mutation.effects, [.stopProjection])
    }

    func testProjectionExternalDisplayLostIsIdempotent() {
        var state = LiveRuntimeState()
        state.projection.isBroadcasting = true
        state.projection.hasExternalDisplay = true
        let first = reduce(state, .projectionExternalDisplayLost)

        let second = reduce(first.state, .projectionExternalDisplayLost, now: Date(timeIntervalSince1970: 101))

        XCTAssertTrue(second.effects.isEmpty)
        XCTAssertEqual(second.state.projection.lastDisplayLostAt, Date(timeIntervalSince1970: 100))
    }

    func testProjectionExternalDisplayAvailableDoesNotAutoStart() {
        let mutation = reduce(LiveRuntimeState(), .projectionExternalDisplayAvailable)

        XCTAssertTrue(mutation.state.projection.hasExternalDisplay)
        XCTAssertFalse(mutation.state.projection.isBroadcasting)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testProjectionExternalDisplayUnavailableDoesNotAutoStart() {
        let mutation = reduce(LiveRuntimeState(), .projectionExternalDisplayUnavailable)

        XCTAssertFalse(mutation.state.projection.hasExternalDisplay)
        XCTAssertFalse(mutation.state.projection.isBroadcasting)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testProjectionReducerDoesNotWriteSupportInProjectionOwnedMode() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true

        let start = reduce(state, .operatorToggledProjection)
        let lost = reduce(start.state, .projectionExternalDisplayLost)

        XCTAssertTrue(start.state.support.events.isEmpty)
        XCTAssertTrue(lost.state.support.events.isEmpty)
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction,
        now: Date = Date(timeIntervalSince1970: 100)
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(now: now, bridgeMode: .projectionOwned)
        )
    }
}
