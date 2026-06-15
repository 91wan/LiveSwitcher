import XCTest
@testable import LiveSwitcher

final class SupportRuntimeReducerBehaviorTests: XCTestCase {
    func testSupportRuntimeReducerRecordsEvent() throws {
        let mutation = record(supportEvent(kind: .projectionStarted, detail: "source=viewModel"))

        let event = try XCTUnwrap(mutation.state.support.events.first)
        XCTAssertEqual(event.kind, .projectionStarted)
        XCTAssertEqual(event.detail, "source=viewModel")
    }

    func testSupportRuntimeReducerRedactsUnsafeDetail() throws {
        let mutation = record(supportEvent(
            kind: .appleScriptFailed,
            detail: "action=keynote.open,error=/Users/operator/private-show.key failed"
        ))

        let event = try XCTUnwrap(mutation.state.support.events.first)
        XCTAssertFalse(event.detail.localizedStandardContains("/Users/"))
        XCTAssertFalse(event.detail.localizedStandardContains("private-show.key"))
    }

    func testSupportRuntimeReducerCoalescesAppleScriptFailures() throws {
        var state = LiveRuntimeState()
        record(supportEvent(kind: .appleScriptFailed, detail: "action=keynote.open,error=failed", timestamp: 100), state: &state)
        let effects = record(
            supportEvent(kind: .appleScriptFailed, detail: "action=keynote.open,error=failed", timestamp: 101),
            state: &state
        )

        let event = try XCTUnwrap(state.support.events.first)
        XCTAssertEqual(state.support.events.count, 1)
        XCTAssertTrue(event.detail.contains("count=2"))
        XCTAssertEqual(effects, [.recordSupportEvent(event)])
    }

    func testSupportRuntimeReducerCoalescesWPSNotRunningEvents() throws {
        var state = LiveRuntimeState()
        record(supportEvent(kind: .pageInterceptWPSNotRunning, detail: "bundle=wps", timestamp: 100), state: &state)
        _ = record(supportEvent(kind: .pageInterceptWPSNotRunning, detail: "bundle=wps", timestamp: 101), state: &state)

        let event = try XCTUnwrap(state.support.events.first)
        XCTAssertEqual(state.support.events.count, 1)
        XCTAssertTrue(event.detail.contains("count=2"))
    }

    func testSupportRuntimeReducerDoesNotCoalesceDistinctDetails() {
        var state = LiveRuntimeState()
        record(supportEvent(kind: .appleScriptFailed, detail: "action=keynote.open,error=failed", timestamp: 100), state: &state)
        _ = record(supportEvent(kind: .appleScriptFailed, detail: "action=keynote.close,error=failed", timestamp: 101), state: &state)

        XCTAssertEqual(state.support.events.count, 2)
    }

    func testSupportRuntimeReducerTrimsToEventLimit() {
        var state = LiveRuntimeState()
        state.support.eventLimit = 2

        record(supportEvent(kind: .projectionStarted, detail: "index=1", timestamp: 100), state: &state)
        record(supportEvent(kind: .projectionStopped, detail: "index=2", timestamp: 101), state: &state)
        _ = record(supportEvent(kind: .preflightAction, detail: "index=3", timestamp: 102), state: &state)

        XCTAssertEqual(state.support.events.count, 2)
    }

    func testSupportRuntimeReducerTrimsLowerPriorityEventsFirst() {
        var state = LiveRuntimeState()
        state.support.eventLimit = 1

        record(supportEvent(kind: .systemVolumeSynced, detail: "volume=0.5", timestamp: 100), state: &state)
        _ = record(supportEvent(kind: .panicModeChanged, detail: "isOn=true", timestamp: 101), state: &state)

        XCTAssertEqual(state.support.events.map(\.kind), [.panicModeChanged])
    }

    func testSupportRuntimeReducerEmitsRecordSupportEffectForAcceptedEvent() throws {
        let mutation = record(supportEvent(kind: .projectionStarted, detail: "source=viewModel"))
        let event = try XCTUnwrap(mutation.state.support.events.first)

        XCTAssertEqual(mutation.effects, [.recordSupportEvent(event)])
    }

    func testSupportRuntimeReducerDoesNotEmitEffectWhenEventTrimmedOut() {
        var state = LiveRuntimeState()
        state.support.eventLimit = 1
        record(supportEvent(kind: .panicModeChanged, detail: "isOn=true", timestamp: 100), state: &state)

        let effects = record(supportEvent(kind: .systemVolumeSynced, detail: "volume=0.5", timestamp: 101), state: &state)

        XCTAssertTrue(effects.isEmpty)
        XCTAssertEqual(state.support.events.map(\.kind), [.panicModeChanged])
    }

    @discardableResult
    private func record(_ event: LiveSupportEvent, state: inout LiveRuntimeState) -> [LiveRuntimeEffect] {
        var effects: [LiveRuntimeEffect] = []
        SupportRuntimeReducer.record(event: event, state: &state, effects: &effects)
        return effects
    }

    private func record(_ event: LiveSupportEvent) -> LiveRuntimeMutation {
        var state = LiveRuntimeState()
        var effects: [LiveRuntimeEffect] = []
        SupportRuntimeReducer.record(event: event, state: &state, effects: &effects)
        return LiveRuntimeMutation(state: state, effects: effects)
    }

    private func supportEvent(
        kind: LiveSupportEventKind,
        detail: String,
        timestamp: TimeInterval = 100
    ) -> LiveSupportEvent {
        LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: timestamp),
            kind: kind,
            detail: detail
        )
    }
}
