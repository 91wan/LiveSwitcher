import XCTest
@testable import LiveSwitcher

final class PPTRuntimeStateTests: XCTestCase {
    func testSetPPTModeOnRequestsStartEffect() {
        let mutation = reduce(.operatorSetPPTMode(true, source: .liveMode))

        XCTAssertTrue(mutation.state.ppt.isRequested)
        XCTAssertFalse(mutation.state.ppt.isEventTapActive)
        XCTAssertNil(mutation.state.ppt.lastFailureReason)
        XCTAssertEqual(mutation.effects, [.startPPTEventTap])
    }

    func testSetPPTModeOnDoesNotMarkActiveBeforeCallback() {
        let mutation = reduce(.operatorSetPPTMode(true, source: .liveMode))

        XCTAssertFalse(mutation.state.ppt.isEventTapActive)
    }

    func testPPTEventTapStartedMarksRequestedAndActive() {
        let mutation = reduce(.pptEventTapStarted)

        XCTAssertTrue(mutation.state.ppt.isRequested)
        XCTAssertTrue(mutation.state.ppt.isEventTapActive)
        XCTAssertNil(mutation.state.ppt.lastFailureReason)
    }

    func testPPTEventTapFailedRollsBackRequestedAndActive() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true

        let mutation = reduce(state, .pptEventTapFailed(reason: "accessibilityPermission"))

        XCTAssertFalse(mutation.state.ppt.isRequested)
        XCTAssertFalse(mutation.state.ppt.isEventTapActive)
        XCTAssertEqual(mutation.state.ppt.lastFailureReason, "accessibilityPermission")
    }

    func testPPTEventTapStoppedClearsRequestedAndActive() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        state.ppt.isEventTapActive = true

        let mutation = reduce(state, .pptEventTapStopped(reason: .operatorDisabled))

        XCTAssertFalse(mutation.state.ppt.isRequested)
        XCTAssertFalse(mutation.state.ppt.isEventTapActive)
    }

    func testSetPPTModeOffRequestsStopEffect() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        state.ppt.isEventTapActive = true

        let mutation = reduce(state, .operatorSetPPTMode(false, source: .liveMode))

        XCTAssertFalse(mutation.state.ppt.isRequested)
        XCTAssertFalse(mutation.state.ppt.isEventTapActive)
        XCTAssertEqual(mutation.effects, [.stopPPTEventTap(reason: .operatorDisabled)])
    }

    func testToggledPPTModeUsesRuntimeStateToChooseOnOrOff() {
        let onMutation = reduce(.operatorToggledPPTMode(source: .liveMode))
        let offMutation = reduce(onMutation.state, .operatorToggledPPTMode(source: .liveMode))

        XCTAssertEqual(onMutation.effects, [.startPPTEventTap])
        XCTAssertEqual(offMutation.effects, [.stopPPTEventTap(reason: .operatorDisabled)])
    }

    func testPPTReducerDoesNotWriteSupportInPPTOwnedMode() {
        [
            reduce(.operatorSetPPTMode(true, source: .liveMode)),
            reduce(.pptEventTapStarted),
            reduce(.pptEventTapFailed(reason: "failed")),
            reduce(.pptEventTapStopped(reason: .operatorDisabled))
        ].forEach { mutation in
            XCTAssertTrue(mutation.state.support.events.isEmpty)
        }
    }

    func testDuplicateSetPPTModeOnNoopsWhenAlreadyRequestedOrActive() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true

        let requested = reduce(state, .operatorSetPPTMode(true, source: .liveMode))
        state.ppt.isEventTapActive = true
        let active = reduce(state, .operatorSetPPTMode(true, source: .liveMode))

        XCTAssertTrue(requested.effects.isEmpty)
        XCTAssertTrue(active.effects.isEmpty)
    }

    func testDuplicateSetPPTModeOffNoopsWhenAlreadyOff() {
        let mutation = reduce(.operatorSetPPTMode(false, source: .liveMode))

        XCTAssertTrue(mutation.effects.isEmpty)
    }

    private func reduce(_ action: LiveRuntimeAction) -> LiveRuntimeMutation {
        reduce(LiveRuntimeState(), action)
    }

    private func reduce(_ state: LiveRuntimeState, _ action: LiveRuntimeAction) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(bridgeMode: .pptOwned)
        )
    }
}
