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

    func testExpiredSuppressionEntriesAreCleanedBeforeNewNotice() {
        var state = LiveRuntimeState()
        state.automation.suppressionUntilByAction = [
            "expired.one": Date(timeIntervalSince1970: 90),
            "expired.two": Date(timeIntervalSince1970: 99)
        ]

        let mutation = reduce(
            state,
            .automationNoticeRequested(action: "keynote.next-slide"),
            now: Date(timeIntervalSince1970: 100)
        )

        XCTAssertNil(mutation.state.automation.suppressionUntilByAction["expired.one"])
        XCTAssertNil(mutation.state.automation.suppressionUntilByAction["expired.two"])
        XCTAssertEqual(
            mutation.state.automation.suppressionUntilByAction["keynote.next-slide"],
            Date(timeIntervalSince1970: 115)
        )
    }

    func testSuppressionMapDoesNotGrowForExpiredSyntheticActions() {
        var state = LiveRuntimeState()

        for index in 0..<20 {
            state.automation.suppressionUntilByAction["synthetic.\(index)"] = Date(timeIntervalSince1970: 100 + Double(index))
            let mutation = reduce(
                state,
                .automationNoticeRequested(action: "synthetic.\(index + 1)"),
                now: Date(timeIntervalSince1970: 200 + Double(index))
            )
            state = mutation.state
        }

        XCTAssertLessThanOrEqual(state.automation.suppressionUntilByAction.count, 1)
        XCTAssertEqual(state.automation.suppressionUntilByAction.keys.first, "synthetic.20")
    }

    func testActiveSuppressionEntryIsPreserved() {
        var state = LiveRuntimeState()
        state.automation.suppressionUntilByAction = [
            "still.active": Date(timeIntervalSince1970: 130),
            "expired": Date(timeIntervalSince1970: 90)
        ]

        let mutation = reduce(
            state,
            .automationNoticeRequested(action: "keynote.next-slide"),
            now: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(
            mutation.state.automation.suppressionUntilByAction["still.active"],
            Date(timeIntervalSince1970: 130)
        )
        XCTAssertNil(mutation.state.automation.suppressionUntilByAction["expired"])
    }

    func testSameActionWithinSuppressionWindowEmitsNoVisibleEffect() throws {
        let first = reduce(.automationNoticeRequested(action: "keynote.next-slide"))
        let firstNotice = try XCTUnwrap(first.state.automation.notice)

        let second = reduce(
            first.state,
            .automationNoticeRequested(action: "keynote.next-slide"),
            now: Date(timeIntervalSince1970: 110)
        )

        XCTAssertEqual(second.state.automation.notice, firstNotice)
        XCTAssertFalse(second.effects.contains { effect in
            if case .showAutomationNotice = effect { return true }
            return false
        })
    }

    func testSameActionAfterSuppressionWindowEmitsVisibleEffect() throws {
        let first = reduce(.automationNoticeRequested(action: "keynote.next-slide"))
        let firstNotice = try XCTUnwrap(first.state.automation.notice)

        let second = reduce(
            first.state,
            .automationNoticeRequested(action: "keynote.next-slide"),
            now: Date(timeIntervalSince1970: 116)
        )

        XCTAssertNotEqual(second.state.automation.notice, firstNotice)
        XCTAssertTrue(second.effects.contains { effect in
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
