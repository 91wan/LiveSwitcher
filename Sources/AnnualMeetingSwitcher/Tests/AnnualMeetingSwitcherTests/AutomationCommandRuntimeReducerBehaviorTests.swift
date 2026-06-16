import XCTest
@testable import LiveSwitcher

final class AutomationCommandRuntimeReducerBehaviorTests: XCTestCase {
    func testAutomationScriptRequestedEmitsRunAppleScriptWhenAutomationCommandOwned() {
        let mutation = reduce(.automationScriptRequested(script: privateScript, action: action), bridgeMode: .automationCommandOwned)

        XCTAssertEqual(mutation.effects, [.runAppleScript(script: privateScript, action: action)])
    }

    func testAutomationScriptRequestedEmitsOnlyRunAppleScriptEffect() {
        let mutation = reduce(.automationScriptRequested(script: privateScript, action: action), bridgeMode: .automationCommandOwned)

        XCTAssertEqual(mutation.effects.count, 1)
        if case .runAppleScript(let script, let emittedAction) = mutation.effects.first {
            XCTAssertEqual(script, privateScript)
            XCTAssertEqual(emittedAction, action)
        } else {
            XCTFail("Expected runAppleScript effect")
        }
    }

    func testAutomationScriptRequestedDoesNotMutateState() {
        var state = LiveRuntimeState()
        state.automation.notice = AutomationRuntimeNoticePolicy.make(action: "keynote.previous-slide")
        state.support.record(kind: .projectionStarted, detail: "source=existing", at: Date(timeIntervalSince1970: 1))

        let mutation = reduce(state, .automationScriptRequested(script: privateScript, action: action), bridgeMode: .automationCommandOwned)

        XCTAssertEqual(mutation.state, state)
    }

    func testAutomationScriptRequestedDoesNotRecordSupport() {
        let mutation = reduce(.automationScriptRequested(script: privateScript, action: action), bridgeMode: .automationCommandOwned)

        XCTAssertTrue(mutation.effects.allSatisfy { effect in
            if case .recordSupportEvent = effect { return false }
            return true
        })
    }

    func testAutomationScriptRequestedDoesNotRequestAutomationNotice() {
        let mutation = reduce(.automationScriptRequested(script: privateScript, action: action), bridgeMode: .automationCommandOwned)

        XCTAssertTrue(mutation.effects.allSatisfy { effect in
            if case .showAutomationNotice = effect { return false }
            return true
        })
    }

    private func reduce(
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        reduce(LiveRuntimeState(), action, bridgeMode: bridgeMode)
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100), bridgeMode: bridgeMode)
        )
    }

    private let privateScript = "tell application \"Keynote\" to open POSIX file \"/Users/operator/private-show.key\""
    private let action = "keynote.open.present"
}
