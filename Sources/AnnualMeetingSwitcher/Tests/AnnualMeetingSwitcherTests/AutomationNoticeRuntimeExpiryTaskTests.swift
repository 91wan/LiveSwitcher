import XCTest
@testable import LiveSwitcher

@MainActor
final class AutomationNoticeRuntimeExpiryTaskTests: XCTestCase {
    func testDismissAutomationNoticeCancelsExpiryTask() {
        let viewModel = makeViewModel()

        viewModel.dispatchRuntimeFacadeAction(.automationNoticeRequested(action: "keynote.next-slide"))
        XCTAssertTrue(viewModel.automationNoticeExpiryTaskIsActiveForTesting)

        viewModel.dismissAutomationRuntimeNotice()

        XCTAssertFalse(viewModel.automationNoticeExpiryTaskIsActiveForTesting)
    }

    func testManualExpireAutomationNoticeCancelsExpiryTask() throws {
        let viewModel = makeViewModel()
        viewModel.dispatchRuntimeFacadeAction(.automationNoticeRequested(action: "keynote.next-slide"))
        let notice = try XCTUnwrap(viewModel.automationRuntimeNotice)
        let expiresAt = try XCTUnwrap(notice.expiresAt)

        viewModel.expireAutomationRuntimeNotice(id: notice.id, now: expiresAt)

        XCTAssertFalse(viewModel.automationNoticeExpiryTaskIsActiveForTesting)
    }

    func testShowingNewAutomationNoticeCancelsPreviousExpiryTask() throws {
        let viewModel = makeViewModel()

        viewModel.dispatchRuntimeFacadeAction(.automationNoticeRequested(action: "keynote.next-slide"))
        let firstTaskNoticeID = try XCTUnwrap(viewModel.automationNoticeExpiryTaskNoticeIDForTesting)

        viewModel.dispatchRuntimeFacadeAction(.automationNoticeRequested(action: "wps.open.command"))

        let currentTaskNoticeID = try XCTUnwrap(viewModel.automationNoticeExpiryTaskNoticeIDForTesting)
        XCTAssertNotEqual(currentTaskNoticeID, firstTaskNoticeID)
        XCTAssertEqual(currentTaskNoticeID, viewModel.automationRuntimeNotice?.id)
    }

    func testStaleScheduledExpiryDoesNotClearNewNotice() throws {
        let viewModel = makeViewModel()

        viewModel.dispatchRuntimeFacadeAction(.automationNoticeRequested(action: "keynote.next-slide"))
        let staleID = try XCTUnwrap(viewModel.automationRuntimeNotice?.id)
        viewModel.dispatchRuntimeFacadeAction(.automationNoticeRequested(action: "wps.open.command"))
        let currentNotice = try XCTUnwrap(viewModel.automationRuntimeNotice)

        viewModel.expireAutomationNoticeFromScheduledTaskForTesting(id: staleID)

        XCTAssertEqual(viewModel.automationRuntimeNotice, currentNotice)
        XCTAssertEqual(viewModel.runtime.state.automation.notice, currentNotice)
    }

    func testStaleScheduledExpiryDoesNotAppendActionLog() throws {
        let viewModel = makeViewModel()

        viewModel.dispatchRuntimeFacadeAction(.automationNoticeRequested(action: "keynote.next-slide"))
        let staleID = try XCTUnwrap(viewModel.automationRuntimeNotice?.id)
        viewModel.dispatchRuntimeFacadeAction(.automationNoticeRequested(action: "wps.open.command"))
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)

        viewModel.expireAutomationNoticeFromScheduledTaskForTesting(id: staleID)

        XCTAssertTrue(viewModel.runtime.actionLog.isEmpty)
    }

    func testExpiryTaskIsCancelledOnViewModelCleanup() {
        let viewModel = makeViewModel()

        viewModel.dispatchRuntimeFacadeAction(.automationNoticeRequested(action: "keynote.next-slide"))
        XCTAssertTrue(viewModel.automationNoticeExpiryTaskIsActiveForTesting)

        viewModel.cleanupBag.cancelAll()

        XCTAssertFalse(viewModel.automationNoticeExpiryTaskIsActiveForTesting)
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "AutomationNoticeRuntimeExpiryTaskTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults
        )
    }
}
