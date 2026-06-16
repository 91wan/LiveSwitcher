import XCTest
@testable import LiveSwitcher

final class ProjectionRuntimeSafetyNoticeTests: XCTestCase {
    func testNoExternalDisplaySafetyNoticeTextUnchanged() {
        let mutation = reduce(LiveRuntimeState(), .operatorToggledProjection)

        XCTAssertEqual(mutation.state.projection.safetyNotice, "未检测到外接屏幕，未开始投射")
    }

    func testExternalDisplayLostSafetyNoticeTextUnchanged() {
        var state = LiveRuntimeState()
        state.projection.isBroadcasting = true
        state.projection.hasExternalDisplay = true

        let mutation = reduce(state, .projectionExternalDisplayLost)

        XCTAssertEqual(mutation.state.projection.safetyNotice, "副屏已断开，投射已停止")
    }

    func testProjectionSafetyNoticeStringsRemainStable() {
        var noDisplayState = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []

        ProjectionRuntimeReducer.toggleProjection(
            state: &noDisplayState,
            effects: &effects,
            canWriteSupport: false,
            now: Date(timeIntervalSince1970: 100)
        )
        XCTAssertEqual(noDisplayState.projection.safetyNotice, "未检测到外接屏幕，未开始投射")

        var displayLostState = LiveRuntimeState()
        displayLostState.projection.isBroadcasting = true
        displayLostState.projection.hasExternalDisplay = true
        effects.removeAll()

        ProjectionRuntimeReducer.externalDisplayUnavailable(
            state: &displayLostState,
            effects: &effects,
            now: Date(timeIntervalSince1970: 101)
        )
        XCTAssertEqual(displayLostState.projection.safetyNotice, "副屏已断开，投射已停止")
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
