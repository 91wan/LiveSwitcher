import XCTest
@testable import LiveSwitcher

final class AutomationNoticeRuntimeReducerBehaviorTests: XCTestCase {
    func testAutomationNoticeRequestCreatesNotice() throws {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []

        AutomationNoticeRuntimeReducer.request(
            action: "keynote.next-slide",
            state: &state,
            effects: &effects,
            now: now
        )

        let notice = try XCTUnwrap(state.automation.notice)
        XCTAssertEqual(notice.action, "keynote.next-slide")
    }

    func testAutomationNoticeRequestUsesAutomationRuntimeNoticePolicy() throws {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []

        AutomationNoticeRuntimeReducer.request(
            action: "keynote.next-slide",
            state: &state,
            effects: &effects,
            now: now
        )

        let notice = try XCTUnwrap(state.automation.notice)
        XCTAssertEqual(notice.title, "翻页未发送")
        XCTAssertEqual(notice.primaryAction, .openSafetyCockpit)
        XCTAssertEqual(notice.createdAt, now)
    }

    func testAutomationNoticeRequestSetsSuppressionUntil() {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []

        AutomationNoticeRuntimeReducer.request(
            action: "keynote.next-slide",
            state: &state,
            effects: &effects,
            now: now
        )

        XCTAssertEqual(state.automation.suppressionUntilByAction["keynote.next-slide"], now.addingTimeInterval(15))
    }

    func testAutomationNoticeRequestEmitsShowNoticeEffect() throws {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []

        AutomationNoticeRuntimeReducer.request(
            action: "keynote.next-slide",
            state: &state,
            effects: &effects,
            now: now
        )

        let notice = try XCTUnwrap(state.automation.notice)
        XCTAssertTrue(effects.contains(.showAutomationNotice(notice)))
    }

    func testAutomationNoticeRequestEmitsExpireEffectWhenNoticeHasExpiry() throws {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []

        AutomationNoticeRuntimeReducer.request(
            action: "keynote.next-slide",
            state: &state,
            effects: &effects,
            now: now
        )

        let notice = try XCTUnwrap(state.automation.notice)
        let expiresAt = try XCTUnwrap(notice.expiresAt)
        XCTAssertTrue(effects.contains(.expireAutomationNotice(notice.id, at: expiresAt)))
    }

    func testAutomationNoticeRequestSuppressesDuplicateWithinSuppressionWindow() throws {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []
        AutomationNoticeRuntimeReducer.request(
            action: "keynote.next-slide",
            state: &state,
            effects: &effects,
            now: now
        )
        let firstNotice = try XCTUnwrap(state.automation.notice)
        effects.removeAll()

        AutomationNoticeRuntimeReducer.request(
            action: "keynote.next-slide",
            state: &state,
            effects: &effects,
            now: now.addingTimeInterval(10)
        )

        XCTAssertEqual(state.automation.notice, firstNotice)
        XCTAssertTrue(effects.isEmpty)
    }

    func testAutomationNoticeRequestAllowsAfterSuppressionExpires() throws {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []
        AutomationNoticeRuntimeReducer.request(
            action: "keynote.next-slide",
            state: &state,
            effects: &effects,
            now: now
        )
        let firstNotice = try XCTUnwrap(state.automation.notice)
        effects.removeAll()

        AutomationNoticeRuntimeReducer.request(
            action: "keynote.next-slide",
            state: &state,
            effects: &effects,
            now: now.addingTimeInterval(16)
        )

        XCTAssertNotEqual(state.automation.notice, firstNotice)
        XCTAssertFalse(effects.isEmpty)
    }

    func testAutomationNoticeRequestPrunesExpiredSuppressionEntries() {
        var state = LiveRuntimeState()
        state.automation.suppressionUntilByAction = [
            "expired": now.addingTimeInterval(-1),
            "active": now.addingTimeInterval(30)
        ]
        var effects: [LiveRuntimeEffect] = []

        AutomationNoticeRuntimeReducer.request(
            action: "keynote.next-slide",
            state: &state,
            effects: &effects,
            now: now
        )

        XCTAssertNil(state.automation.suppressionUntilByAction["expired"])
        XCTAssertEqual(state.automation.suppressionUntilByAction["active"], now.addingTimeInterval(30))
    }

    func testAutomationNoticeExpireClearsMatchingNotice() {
        var state = LiveRuntimeState()
        let notice = AutomationRuntimeNoticePolicy.make(action: "keynote.next-slide")
        state.automation.notice = notice

        AutomationNoticeRuntimeReducer.expire(id: notice.id, state: &state)

        XCTAssertNil(state.automation.notice)
    }

    func testAutomationNoticeExpireDoesNotClearDifferentNotice() {
        var state = LiveRuntimeState()
        let notice = AutomationRuntimeNoticePolicy.make(action: "keynote.next-slide")
        state.automation.notice = notice

        AutomationNoticeRuntimeReducer.expire(id: UUID(), state: &state)

        XCTAssertEqual(state.automation.notice, notice)
    }

    func testAutomationNoticeDismissClearsNotice() {
        var state = LiveRuntimeState()
        state.automation.notice = AutomationRuntimeNoticePolicy.make(action: "keynote.next-slide")

        AutomationNoticeRuntimeReducer.dismiss(state: &state)

        XCTAssertNil(state.automation.notice)
    }

    func testAutomationNoticeDismissDoesNotClearSuppressionMap() {
        var state = LiveRuntimeState()
        state.automation.notice = AutomationRuntimeNoticePolicy.make(action: "keynote.next-slide")
        state.automation.suppressionUntilByAction = ["keynote.next-slide": now.addingTimeInterval(15)]

        AutomationNoticeRuntimeReducer.dismiss(state: &state)

        XCTAssertEqual(state.automation.suppressionUntilByAction["keynote.next-slide"], now.addingTimeInterval(15))
    }

    private let now = Date(timeIntervalSince1970: 100)
}
