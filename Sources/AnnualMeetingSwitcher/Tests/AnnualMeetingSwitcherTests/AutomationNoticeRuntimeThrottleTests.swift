import XCTest
@testable import LiveSwitcher

final class AutomationNoticeRuntimeThrottleTests: XCTestCase {
    func testRepeatedAutomationFailureSuppressesRepeatedVisibleNotice() throws {
        let first = reduce(.automationFailed(action: "keynote.next-slide", sanitizedMessage: "failed"))
        let firstNotice = try XCTUnwrap(first.state.automation.notice)

        let second = reduce(
            first.state,
            .automationFailed(action: "keynote.next-slide", sanitizedMessage: "failed again"),
            now: Date(timeIntervalSince1970: 105)
        )

        XCTAssertEqual(second.state.automation.notice, firstNotice)
        XCTAssertFalse(second.effects.contains { effect in
            if case .showAutomationNotice = effect { return true }
            return false
        })
    }

    func testSuppressionExpiresAfterWindow() throws {
        let first = reduce(.automationNoticeRequested(action: "keynote.next-slide"))
        let firstNotice = try XCTUnwrap(first.state.automation.notice)

        let later = reduce(
            first.state,
            .automationNoticeRequested(action: "keynote.next-slide"),
            now: Date(timeIntervalSince1970: 116)
        )

        XCTAssertNotEqual(later.state.automation.notice, firstNotice)
        XCTAssertTrue(later.effects.contains { effect in
            if case .showAutomationNotice = effect { return true }
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
