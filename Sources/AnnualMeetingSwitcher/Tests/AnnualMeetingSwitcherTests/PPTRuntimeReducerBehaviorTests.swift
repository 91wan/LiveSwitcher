import XCTest
@testable import LiveSwitcher

final class PPTRuntimeReducerBehaviorTests: XCTestCase {
    func testSetPPTModeEnabledRequestsStartWhenIdle() {
        var state = LiveRuntimeState()
        state.ppt.lastFailureReason = "previousFailure"
        var effects: [LiveRuntimeEffect] = []

        PPTRuntimeReducer.setMode(true, source: .liveMode, state: &state, effects: &effects)

        XCTAssertTrue(state.ppt.isRequested)
        XCTAssertFalse(state.ppt.isEventTapActive)
        XCTAssertNil(state.ppt.lastFailureReason)
        XCTAssertEqual(effects, [.startPPTEventTap])
    }

    func testSetPPTModeEnabledClearsLastFailure() {
        var state = LiveRuntimeState()
        state.ppt.lastFailureReason = "previousFailure"
        var effects: [LiveRuntimeEffect] = []

        PPTRuntimeReducer.setMode(true, source: .liveMode, state: &state, effects: &effects)

        XCTAssertNil(state.ppt.lastFailureReason)
    }

    func testSetPPTModeEnabledEmitsStartPPTEventTap() {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []

        PPTRuntimeReducer.setMode(true, source: .liveMode, state: &state, effects: &effects)

        XCTAssertEqual(effects, [.startPPTEventTap])
    }

    func testSetPPTModeEnabledNoopsWhenAlreadyRequested() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        var effects: [LiveRuntimeEffect] = []

        PPTRuntimeReducer.setMode(true, source: .liveMode, state: &state, effects: &effects)

        XCTAssertTrue(effects.isEmpty)
        XCTAssertTrue(state.ppt.isRequested)
    }

    func testSetPPTModeEnabledNoopsWhenAlreadyActive() {
        var state = LiveRuntimeState()
        state.ppt.isEventTapActive = true
        var effects: [LiveRuntimeEffect] = []

        PPTRuntimeReducer.setMode(true, source: .liveMode, state: &state, effects: &effects)

        XCTAssertTrue(effects.isEmpty)
        XCTAssertTrue(state.ppt.isEventTapActive)
    }

    func testSetPPTModeDisabledRequestsStopWhenRequested() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        var effects: [LiveRuntimeEffect] = []

        PPTRuntimeReducer.setMode(false, source: .liveMode, state: &state, effects: &effects)

        XCTAssertFalse(state.ppt.isRequested)
        XCTAssertFalse(state.ppt.isEventTapActive)
        XCTAssertEqual(effects, [.stopPPTEventTap(reason: .operatorDisabled)])
    }

    func testSetPPTModeDisabledRequestsStopWhenActive() {
        var state = LiveRuntimeState()
        state.ppt.isEventTapActive = true
        var effects: [LiveRuntimeEffect] = []

        PPTRuntimeReducer.setMode(false, source: .liveMode, state: &state, effects: &effects)

        XCTAssertFalse(state.ppt.isRequested)
        XCTAssertFalse(state.ppt.isEventTapActive)
        XCTAssertEqual(effects, [.stopPPTEventTap(reason: .operatorDisabled)])
    }

    func testSetPPTModeDisabledNoopsWhenAlreadyIdle() {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []

        PPTRuntimeReducer.setMode(false, source: .liveMode, state: &state, effects: &effects)

        XCTAssertTrue(effects.isEmpty)
        XCTAssertFalse(state.ppt.isRequested)
        XCTAssertFalse(state.ppt.isEventTapActive)
    }

    func testTogglePPTModeStartsWhenIdleAndStopsWhenActiveOrRequested() {
        var idle = LiveRuntimeState()
        var idleEffects: [LiveRuntimeEffect] = []
        PPTRuntimeReducer.toggleMode(source: .liveMode, state: &idle, effects: &idleEffects)
        XCTAssertEqual(idleEffects, [.startPPTEventTap])

        var requested = LiveRuntimeState()
        requested.ppt.isRequested = true
        var requestedEffects: [LiveRuntimeEffect] = []
        PPTRuntimeReducer.toggleMode(source: .liveMode, state: &requested, effects: &requestedEffects)
        XCTAssertEqual(requestedEffects, [.stopPPTEventTap(reason: .operatorDisabled)])

        var active = LiveRuntimeState()
        active.ppt.isEventTapActive = true
        var activeEffects: [LiveRuntimeEffect] = []
        PPTRuntimeReducer.toggleMode(source: .command, state: &active, effects: &activeEffects)
        XCTAssertEqual(activeEffects, [.stopPPTEventTap(reason: .operatorDisabled)])
    }

    func testPPTEventTapCallbacksPreserveExistingBehavior() {
        var state = LiveRuntimeState()
        state.ppt.lastFailureReason = "previousFailure"

        PPTRuntimeReducer.eventTapStarted(state: &state)
        XCTAssertTrue(state.ppt.isRequested)
        XCTAssertTrue(state.ppt.isEventTapActive)
        XCTAssertNil(state.ppt.lastFailureReason)

        PPTRuntimeReducer.eventTapFailed(reason: "permissionDenied", state: &state)
        XCTAssertFalse(state.ppt.isRequested)
        XCTAssertFalse(state.ppt.isEventTapActive)
        XCTAssertEqual(state.ppt.lastFailureReason, "permissionDenied")

        PPTRuntimeReducer.eventTapStopped(reason: .operatorDisabled, state: &state)
        XCTAssertFalse(state.ppt.isRequested)
        XCTAssertFalse(state.ppt.isEventTapActive)
        XCTAssertEqual(state.ppt.lastFailureReason, "permissionDenied")
    }

    func testPPTEventTapStartedSetsRequestedAndActive() {
        var state = LiveRuntimeState()

        PPTRuntimeReducer.eventTapStarted(state: &state)

        XCTAssertTrue(state.ppt.isRequested)
        XCTAssertTrue(state.ppt.isEventTapActive)
    }

    func testPPTEventTapFailedStoresFailureReason() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true

        PPTRuntimeReducer.eventTapFailed(reason: "permissionDenied", state: &state)

        XCTAssertEqual(state.ppt.lastFailureReason, "permissionDenied")
    }

    func testPPTEventTapStoppedClearsRequestedAndActive() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        state.ppt.isEventTapActive = true

        PPTRuntimeReducer.eventTapStopped(reason: .operatorDisabled, state: &state)

        XCTAssertFalse(state.ppt.isRequested)
        XCTAssertFalse(state.ppt.isEventTapActive)
    }
}
