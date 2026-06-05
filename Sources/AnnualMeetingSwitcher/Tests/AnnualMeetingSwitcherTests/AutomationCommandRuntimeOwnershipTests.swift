import XCTest
@testable import LiveSwitcher

final class AutomationCommandRuntimeOwnershipTests: XCTestCase {
    func testAutomationScriptRequestedEmitsRunAppleScriptEffectWhenCommandOwned() {
        let mutation = reduce(
            .automationScriptRequested(script: "tell application \"Keynote\"", action: "keynote.next-slide"),
            bridgeMode: .automationCommandOwned
        )

        XCTAssertEqual(
            mutation.effects,
            [.runAppleScript(script: "tell application \"Keynote\"", action: "keynote.next-slide")]
        )
    }

    func testAutomationScriptRequestedDoesNotEmitRunAppleScriptBeforeCommandOwnership() {
        let mutation = reduce(
            .automationScriptRequested(script: "tell application \"Keynote\"", action: "keynote.next-slide"),
            bridgeMode: .supportOwned
        )

        XCTAssertFalse(mutation.effects.contains {
            if case .runAppleScript = $0 { return true }
            return false
        })
    }

    func testAutomationScriptRequestedDoesNotMutateSupportState() {
        var state = LiveRuntimeState()
        state.support.record(
            kind: .projectionStarted,
            detail: "source=existing",
            at: Date(timeIntervalSince1970: 1)
        )

        let mutation = reduce(
            state,
            .automationScriptRequested(script: "tell application \"Keynote\"", action: "keynote.next-slide"),
            bridgeMode: .automationCommandOwned
        )

        XCTAssertEqual(mutation.state.support, state.support)
    }

    func testAutomationScriptRequestedDoesNotMutateAutomationNoticeState() {
        var state = LiveRuntimeState()
        state.automation.notice = AutomationRuntimeNoticePolicy.make(
            action: "keynote.previous-slide",
            createdAt: Date(timeIntervalSince1970: 1)
        )

        let mutation = reduce(
            state,
            .automationScriptRequested(script: "tell application \"Keynote\"", action: "keynote.next-slide"),
            bridgeMode: .automationCommandOwned
        )

        XCTAssertEqual(mutation.state.automation, state.automation)
        XCTAssertFalse(mutation.effects.contains {
            if case .showAutomationNotice = $0 { return true }
            return false
        })
    }

    func testRunAppleScriptEffectRequiresAutomationCommandDomain() {
        XCTAssertEqual(
            LiveRuntimeEffect.runAppleScript(script: "tell application \"Keynote\"", action: "keynote.next-slide").requiredBridgeDomain,
            .automationCommand
        )
    }

    func testAutomationCommandOwnedModeAllowsRunAppleScriptEffect() {
        XCTAssertTrue(LiveRuntimeBridgeMode.automationCommandOwned.owns(.automationCommand))
    }

    func testSupportOwnedModeBlocksRunAppleScriptEffect() {
        XCTAssertFalse(LiveRuntimeBridgeMode.supportOwned.owns(.automationCommand))
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
}
