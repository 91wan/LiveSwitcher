import XCTest
@testable import LiveSwitcher

final class PPTRuntimeEffectTests: XCTestCase {
    func testPPTEventTapEffectsRequirePPTDomain() {
        XCTAssertEqual(LiveRuntimeEffect.startPPTEventTap.requiredBridgeDomain, .ppt)
        XCTAssertEqual(LiveRuntimeEffect.stopPPTEventTap(reason: .operatorDisabled).requiredBridgeDomain, .ppt)
    }

    func testSetPPTModeEnabledEmitsOnlyStartEventTapEffect() {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []

        PPTRuntimeReducer.setMode(true, source: .liveMode, state: &state, effects: &effects)

        XCTAssertEqual(effects, [.startPPTEventTap])
    }

    func testSetPPTModeDisabledEmitsOnlyStopEventTapEffect() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        var effects: [LiveRuntimeEffect] = []

        PPTRuntimeReducer.setMode(false, source: .liveMode, state: &state, effects: &effects)

        XCTAssertEqual(effects, [.stopPPTEventTap(reason: .operatorDisabled)])
    }

    func testPPTCallbacksDoNotEmitEffects() {
        let actions: [LiveRuntimeAction] = [
            .pptEventTapStarted,
            .pptEventTapFailed(reason: "permissionDenied"),
            .pptEventTapStopped(reason: .operatorDisabled)
        ]

        for action in actions {
            let mutation = LiveRuntimeReducer.reduce(
                state: LiveRuntimeState(),
                action: action,
                environment: .productionPPTOwning()
            )

            XCTAssertTrue(mutation.effects.isEmpty, "Unexpected effects for \(action.redactedName)")
        }
    }
}
