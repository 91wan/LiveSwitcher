import XCTest
@testable import LiveSwitcher

final class ProjectionRuntimeSafetyNoticeTests: XCTestCase {
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
}
