import XCTest
@testable import LiveSwitcher

@MainActor
final class SupportRuntimeOwnershipTests: XCTestCase {
    func testSupportOwnedModeOwnsPriorDomainsAndSupport() {
        XCTAssertEqual(
            LiveRuntimeBridgeMode.supportOwned.ownedDomains,
            [.audio, .media, .bgm, .projection, .ppt, .automationNotice, .support, .imageAssets, .persistence]
        )
    }

    func testSupportOwnedModeDoesNotOwnAutomationExecution() {
        XCTAssertFalse(LiveRuntimeBridgeMode.supportOwned.owns(.automation))
    }

    func testProductionEnvironmentIsSupportOwned() {
        XCTAssertEqual(LiveRuntimeEnvironment.productionSupportOwning().bridgeMode, .supportOwned)
    }

    func testProductionViewModelUsesProgramSelectionOwnedRuntime() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        XCTAssertEqual(viewModel.runtimeBridgeMode, .programActivationOwned)
        XCTAssertTrue(viewModel.runtimeBridgeMode.owns(.support))
        XCTAssertTrue(viewModel.runtimeBridgeMode.owns(.automationCommand))
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
