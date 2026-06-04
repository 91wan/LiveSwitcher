import XCTest
@testable import LiveSwitcher

final class AutomationNoticeRuntimeStateTests: XCTestCase {
    func testAutomationNoticeRequestedCreatesNotice() throws {
        let mutation = reduce(.automationNoticeRequested(action: "keynote.next-slide"))

        let notice = try XCTUnwrap(mutation.state.automation.notice)
        XCTAssertEqual(notice.action, "keynote.next-slide")
        XCTAssertEqual(notice.title, "翻页未发送")
    }

    func testAutomationNoticeRequestedEmitsShowNoticeEffect() {
        let mutation = reduce(.automationNoticeRequested(action: "keynote.next-slide"))

        XCTAssertTrue(mutation.effects.contains { effect in
            if case .showAutomationNotice(let notice) = effect {
                return notice.action == "keynote.next-slide"
            }
            return false
        })
    }

    func testAutomationNoticeRequestedEmitsExpireNoticeEffectWhenNoticeHasExpiry() {
        let mutation = reduce(.automationNoticeRequested(action: "keynote.next-slide"))

        XCTAssertTrue(mutation.effects.contains { effect in
            if case .expireAutomationNotice(let id, let expiresAt) = effect {
                return id == mutation.state.automation.notice?.id
                    && expiresAt == mutation.state.automation.notice?.expiresAt
            }
            return false
        })
    }

    func testAutomationNoticeSuppressionPreventsRepeatedVisibleNotice() throws {
        let first = reduce(.automationNoticeRequested(action: "keynote.next-slide"))
        let firstNotice = try XCTUnwrap(first.state.automation.notice)

        let second = reduce(
            first.state,
            .automationNoticeRequested(action: "keynote.next-slide"),
            now: Date(timeIntervalSince1970: 105)
        )

        XCTAssertEqual(second.state.automation.notice, firstNotice)
        XCTAssertTrue(second.effects.isEmpty)
    }

    func testDifferentAutomationActionCreatesNewNotice() throws {
        let first = reduce(.automationNoticeRequested(action: "keynote.next-slide"))
        let firstNotice = try XCTUnwrap(first.state.automation.notice)

        let second = reduce(
            first.state,
            .automationNoticeRequested(action: "wps.open.command"),
            now: Date(timeIntervalSince1970: 105)
        )

        let secondNotice = try XCTUnwrap(second.state.automation.notice)
        XCTAssertNotEqual(secondNotice, firstNotice)
        XCTAssertEqual(secondNotice.action, "wps.open.command")
    }

    func testAutomationNoticeExpiredClearsMatchingNotice() throws {
        let requested = reduce(.automationNoticeRequested(action: "keynote.next-slide"))
        let notice = try XCTUnwrap(requested.state.automation.notice)

        let expired = reduce(requested.state, .automationNoticeExpired(notice.id))

        XCTAssertNil(expired.state.automation.notice)
    }

    func testAutomationNoticeExpiredIgnoresStaleID() throws {
        let requested = reduce(.automationNoticeRequested(action: "keynote.next-slide"))
        let notice = try XCTUnwrap(requested.state.automation.notice)

        let expired = reduce(requested.state, .automationNoticeExpired(UUID()))

        XCTAssertEqual(expired.state.automation.notice, notice)
    }

    func testAutomationNoticeDismissedClearsNotice() {
        let requested = reduce(.automationNoticeRequested(action: "keynote.next-slide"))

        let dismissed = reduce(requested.state, .automationNoticeDismissed)

        XCTAssertNil(dismissed.state.automation.notice)
    }

    func testAutomationFailedCreatesNoticeWithoutReducerSupportWrite() throws {
        let mutation = reduce(.automationFailed(action: "keynote.next-slide", sanitizedMessage: "failed"))

        XCTAssertEqual(try XCTUnwrap(mutation.state.automation.notice).action, "keynote.next-slide")
        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testAutomationFailedDoesNotEmitRunAppleScript() {
        let mutation = reduce(.automationFailed(action: "keynote.next-slide", sanitizedMessage: "failed"))

        XCTAssertFalse(mutation.effects.contains { effect in
            if case .runAppleScript = effect { return true }
            return false
        })
    }

    private func reduce(
        _ action: LiveRuntimeAction,
        now: Date = Date(timeIntervalSince1970: 100)
    ) -> LiveRuntimeMutation {
        reduce(LiveRuntimeState(), action, now: now)
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction,
        now: Date = Date(timeIntervalSince1970: 100)
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: .productionAutomationNoticeOwning(now: now)
        )
    }
}
