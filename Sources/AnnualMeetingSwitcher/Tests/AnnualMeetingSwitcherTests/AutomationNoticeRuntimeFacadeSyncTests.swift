import XCTest
@testable import LiveSwitcher

@MainActor
final class AutomationNoticeRuntimeFacadeSyncTests: XCTestCase {
    func testAutomationNoticeOwnedFacadeSyncPreservesRuntimeNotice() throws {
        var state = LiveRuntimeState()
        let runtimeNotice = AutomationRuntimeNoticePolicy.make(action: "keynote.next-slide")
        state.automation.notice = runtimeNotice
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .automationNoticeOwned)
        viewModel.automationRuntimeNotice = AutomationRuntimeNoticePolicy.make(action: "wps.open.command")

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.automation.notice, runtimeNotice)
    }

    func testAutomationNoticeOwnedFacadeSyncPreservesSuppressionMap() {
        var state = LiveRuntimeState()
        let suppression = Date(timeIntervalSince1970: 500)
        state.automation.suppressionUntilByAction = ["keynote.next-slide": suppression]
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .automationNoticeOwned)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.automation.suppressionUntilByAction["keynote.next-slide"], suppression)
    }

    func testNonAutomationNoticeOwnedFacadeSyncMirrorsViewModelNotice() {
        let viewModel = makeViewModel(runtimeState: LiveRuntimeState(), bridgeMode: .pptOwned)
        let notice = AutomationRuntimeNoticePolicy.make(action: "keynote.next-slide")
        viewModel.automationRuntimeNotice = notice

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.automation.notice, notice)
    }

    func testAutomationNoticeRequestedSyncsFacadeNotice() throws {
        let viewModel = makeViewModel()

        viewModel.dispatchRuntimeFacadeAction(.automationNoticeRequested(action: "keynote.next-slide"))

        XCTAssertEqual(try XCTUnwrap(viewModel.automationRuntimeNotice).action, "keynote.next-slide")
    }

    func testAutomationNoticeExpiredSyncsFacadeClear() throws {
        let viewModel = makeViewModel()
        viewModel.dispatchRuntimeFacadeAction(.automationNoticeRequested(action: "keynote.next-slide"))
        let notice = try XCTUnwrap(viewModel.automationRuntimeNotice)

        viewModel.dispatchRuntimeFacadeAction(.automationNoticeExpired(notice.id))

        XCTAssertNil(viewModel.automationRuntimeNotice)
    }

    func testAutomationNoticeDismissedSyncsFacadeClear() {
        let viewModel = makeViewModel()
        viewModel.dispatchRuntimeFacadeAction(.automationNoticeRequested(action: "keynote.next-slide"))

        viewModel.dispatchRuntimeFacadeAction(.automationNoticeDismissed)

        XCTAssertNil(viewModel.automationRuntimeNotice)
    }

    private func makeViewModel(
        runtimeState: LiveRuntimeState = LiveRuntimeState(),
        bridgeMode: LiveRuntimeBridgeMode = .automationNoticeOwned
    ) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        runtime.replaceStateForFacadeSync(runtimeState, clearActionLog: true)
        let suiteName = "AutomationNoticeRuntimeFacadeSyncTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults,
            runtime: runtime
        )
    }
}
