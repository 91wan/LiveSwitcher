import XCTest
@testable import LiveSwitcher

@MainActor
final class AutomationNoticeRuntimeActionLogTests: XCTestCase {
    func testAutomationFailedIsLogged() {
        let runtime = makeRuntime()

        runtime.dispatch(.automationFailed(action: "keynote.next-slide", sanitizedMessage: "failed"))

        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "automationFailed" })
    }

    func testAutomationNoticeRequestedIsNotLogged() {
        let runtime = makeRuntime()

        runtime.dispatch(.automationNoticeRequested(action: "keynote.next-slide"))

        XCTAssertFalse(runtime.actionLog.contains { $0.actionName == "automationNoticeRequested" })
    }

    func testAutomationNoticeExpiredIsNotLogged() {
        let notice = AutomationRuntimeNoticePolicy.make(
            action: "keynote.next-slide",
            createdAt: Date(timeIntervalSince1970: 100)
        )
        var state = LiveRuntimeState()
        state.automation.notice = notice
        let runtime = makeRuntime(initialState: state)

        runtime.dispatch(.automationNoticeExpired(notice.id))

        XCTAssertFalse(runtime.actionLog.contains { $0.actionName == "automationNoticeExpired" })
    }

    func testAutomationNoticeDismissedIsLogged() {
        var state = LiveRuntimeState()
        state.automation.notice = AutomationRuntimeNoticePolicy.make(action: "keynote.next-slide")
        let runtime = makeRuntime(initialState: state)

        runtime.dispatch(.automationNoticeDismissed)

        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "automationNoticeDismissed" })
    }

    func testAutomationNoticeActionLogDoesNotContainNoticeText() {
        let runtime = makeRuntime()

        runtime.dispatch(.automationNoticeDismissed)

        XCTAssertFalse(runtime.actionLog.contains { entry in
            entry.oldStateSummary.localizedStandardContains("翻页未发送")
                || entry.newStateSummary.localizedStandardContains("翻页未发送")
        })
    }

    func testAutomationFailedActionLogDoesNotContainSanitizedMessage() {
        let runtime = makeRuntime()

        runtime.dispatch(.automationFailed(action: "keynote.next-slide", sanitizedMessage: "raw script /Users/operator/private.key"))

        XCTAssertFalse(runtime.actionLog.contains { entry in
            entry.oldStateSummary.localizedStandardContains("raw script")
                || entry.newStateSummary.localizedStandardContains("raw script")
                || entry.oldStateSummary.localizedStandardContains("/Users/operator")
                || entry.newStateSummary.localizedStandardContains("/Users/operator")
        })
    }

    func testRepeatedSuppressedAutomationNoticeDoesNotGrowActionLog() {
        let runtime = makeRuntime()

        runtime.dispatch(.automationNoticeRequested(action: "keynote.next-slide"))
        runtime.dispatch(.automationNoticeRequested(action: "keynote.next-slide"))

        XCTAssertTrue(runtime.actionLog.isEmpty)
    }

    private func makeRuntime(initialState: LiveRuntimeState = LiveRuntimeState()) -> LiveRuntimeStore {
        LiveRuntimeStore(
            initialState: initialState,
            environment: .productionAutomationNoticeOwning(now: Date(timeIntervalSince1970: 100))
        )
    }
}
