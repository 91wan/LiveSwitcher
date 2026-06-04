import XCTest
@testable import LiveSwitcher

@MainActor
final class AutomationNoticeRuntimePortContractTests: XCTestCase {
    func testProductionRuntimeWiresAutomationNoticePort() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertTrue(viewModel.runtimeConnectedPortKinds.contains(.automationNotice))
    }

    func testProductionRuntimeDoesNotWireAutomationExecutionPort() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertFalse(viewModel.runtimeConnectedPortKinds.contains(.automation))
    }

    func testProductionRuntimeDoesNotWireSupportPort() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertFalse(viewModel.runtimeConnectedPortKinds.contains(.support))
    }

    func testRunAppleScriptEffectRequiresAutomationDomain() {
        XCTAssertEqual(
            LiveRuntimeEffect.runAppleScript(script: "tell app", action: "keynote.next-slide").requiredBridgeDomain,
            .automation
        )
    }

    func testAutomationNoticeOwnedModeBlocksRunAppleScriptEffect() {
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .automationFailed(action: "keynote.next-slide", sanitizedMessage: "failed"),
            environment: LiveRuntimeEnvironment(bridgeMode: .automationNoticeOwned)
        )

        XCTAssertFalse(mutation.effects.contains { effect in
            if case .runAppleScript = effect { return true }
            return false
        })
    }

    func testAutomationNoticeOwnedModeAllowsShowAutomationNoticeEffect() {
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .automationNoticeRequested(action: "keynote.next-slide"),
            environment: LiveRuntimeEnvironment(bridgeMode: .automationNoticeOwned)
        )

        XCTAssertTrue(mutation.effects.contains { effect in
            if case .showAutomationNotice = effect { return true }
            return false
        })
    }
}
