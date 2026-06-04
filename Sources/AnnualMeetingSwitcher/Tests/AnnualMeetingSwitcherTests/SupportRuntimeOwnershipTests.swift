import XCTest
@testable import LiveSwitcher

@MainActor
final class SupportRuntimeOwnershipTests: XCTestCase {
    func testSupportOwnedModeOwnsPriorDomainsAndSupport() {
        XCTAssertEqual(
            LiveRuntimeBridgeMode.supportOwned.ownedDomains,
            [.audio, .media, .bgm, .projection, .ppt, .automationNotice, .support]
        )
    }

    func testSupportOwnedModeDoesNotOwnAutomationExecution() {
        XCTAssertFalse(LiveRuntimeBridgeMode.supportOwned.owns(.automation))
    }

    func testProductionEnvironmentIsSupportOwned() {
        XCTAssertEqual(LiveRuntimeEnvironment.productionSupportOwning().bridgeMode, .supportOwned)
    }

    func testProductionViewModelUsesSupportOwnedRuntime() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .supportOwned)
        XCTAssertTrue(viewModel.runtimeBridgeMode.owns(.support))
        XCTAssertFalse(viewModel.runtimeBridgeMode.owns(.automation))
    }

    func testSupportRuntimeStateIsAuthoritativeWhenSupportOwned() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        var state = viewModel.runtime.state
        state.support.record(
            kind: .preflightAction,
            detail: "action=manualReview",
            at: Date(timeIntervalSince1970: 100)
        )

        viewModel.runtime.replaceStateForFacadeSync(state, clearActionLog: false)
        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.support, state.support)
    }
}
