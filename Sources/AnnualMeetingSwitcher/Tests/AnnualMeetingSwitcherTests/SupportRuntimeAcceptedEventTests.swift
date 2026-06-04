import XCTest
@testable import LiveSwitcher

final class SupportRuntimeAcceptedEventTests: XCTestCase {
    func testRecordReturnsSanitizedAcceptedEventFromRuntimeState() throws {
        var state = SupportRuntimeState()
        let raw = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .appleScriptFailed,
            detail: "action=keynote.open,error=/Users/operator/private-show.key failed"
        )

        let accepted = try XCTUnwrap(state.record(event: raw))

        XCTAssertEqual(accepted, state.events.last)
        XCTAssertEqual(accepted.kind, .appleScriptFailed)
        XCTAssertFalse(accepted.detail.localizedStandardContains("/Users/"))
        XCTAssertFalse(accepted.detail.localizedStandardContains("private-show.key"))
    }

    func testRecordReturnsCoalescedAcceptedEventFromRuntimeState() throws {
        var state = SupportRuntimeState()
        let first = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .appleScriptFailed,
            detail: "action=keynote.open,error=failed"
        )
        let second = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 101),
            kind: .appleScriptFailed,
            detail: "action=keynote.open,error=failed"
        )

        _ = state.record(event: first)
        let accepted = try XCTUnwrap(state.record(event: second))

        XCTAssertEqual(accepted, state.events.last)
        XCTAssertEqual(state.events.count, 1)
        XCTAssertTrue(accepted.detail.contains("count=2"))
        XCTAssertTrue(accepted.detail.contains("lastSeen="))
    }

    func testRecordReturnsNilIfLowPriorityEventIsTrimmedImmediately() {
        var state = SupportRuntimeState()
        state.eventLimit = 1
        _ = state.record(event: LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .panicModeChanged,
            detail: "isOn=true"
        ))

        let accepted = state.record(event: LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 101),
            kind: .systemVolumeSynced,
            detail: "deviceID=1,volume=0.5"
        ))

        XCTAssertNil(accepted)
        XCTAssertEqual(state.events.map(\.kind), [.panicModeChanged])
    }

    func testReducerRecordSupportEffectUsesAcceptedSanitizedEvent() throws {
        let raw = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .appleScriptFailed,
            detail: "action=keynote.open,error=/Users/operator/private-show.key failed"
        )

        let mutation = reduce(.supportEventRecorded(raw), bridgeMode: .supportOwned)
        let recorded = try XCTUnwrap(mutation.state.support.events.first)

        XCTAssertEqual(mutation.effects, [.recordSupportEvent(recorded)])
        XCTAssertFalse(recorded.detail.localizedStandardContains("/Users/"))
        XCTAssertFalse(recorded.detail.localizedStandardContains("private-show.key"))
    }

    func testRecordSupportEffectDoesNotExposeRawFilePath() throws {
        let raw = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .appleScriptFailed,
            detail: "path=/Users/operator/private-show.key,error=failed"
        )

        let mutation = reduce(.supportEventRecorded(raw), bridgeMode: .supportOwned)
        let effect = try XCTUnwrap(mutation.effects.first)
        guard case .recordSupportEvent(let accepted) = effect else {
            return XCTFail("Expected recordSupportEvent effect")
        }

        XCTAssertFalse(accepted.detail.localizedStandardContains("/Users/"))
        XCTAssertFalse(accepted.detail.localizedStandardContains("private-show.key"))
    }

    func testReducerRecordSupportEffectUsesCoalescedAcceptedEventAfterRepeat() throws {
        let first = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .appleScriptFailed,
            detail: "action=keynote.open,error=failed"
        )
        let second = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 101),
            kind: .appleScriptFailed,
            detail: "action=keynote.open,error=failed"
        )

        let firstMutation = reduce(.supportEventRecorded(first), bridgeMode: .supportOwned)
        let secondMutation = reduce(firstMutation.state, .supportEventRecorded(second), bridgeMode: .supportOwned)
        let recorded = try XCTUnwrap(secondMutation.state.support.events.first)

        XCTAssertEqual(secondMutation.effects, [.recordSupportEvent(recorded)])
        XCTAssertTrue(recorded.detail.contains("count=2"))
        XCTAssertNotEqual(recorded, second)
    }

    func testReducerDoesNotEmitRecordSupportEffectWhenEventIsTrimmedImmediately() {
        var state = LiveRuntimeState()
        state.support.eventLimit = 1
        state.support.record(kind: .panicModeChanged, detail: "isOn=true", at: Date(timeIntervalSince1970: 100))

        let lowPriority = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 101),
            kind: .systemVolumeSynced,
            detail: "deviceID=1,volume=0.5"
        )
        let mutation = reduce(state, .supportEventRecorded(lowPriority), bridgeMode: .supportOwned)

        XCTAssertTrue(mutation.effects.isEmpty)
        XCTAssertEqual(mutation.state.support.events.map(\.kind), [.panicModeChanged])
    }

    private func reduce(
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        reduce(LiveRuntimeState(), action, bridgeMode: bridgeMode)
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100), bridgeMode: bridgeMode)
        )
    }
}
