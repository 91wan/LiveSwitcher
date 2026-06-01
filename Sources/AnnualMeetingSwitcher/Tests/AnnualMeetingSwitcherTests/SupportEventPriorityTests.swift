import XCTest
@testable import LiveSwitcher

final class SupportEventPriorityTests: XCTestCase {
    func testLowPriorityOverflowDoesNotEvictCriticalEvents() {
        var state = SupportRuntimeState()
        state.eventLimit = 8
        let start = Date(timeIntervalSince1970: 1_790_000_000)

        state.record(kind: .panicModeChanged, detail: "isOn=true", at: start)
        state.record(kind: .projectionLost, detail: "externalDisplay=false", at: start.addingTimeInterval(1))
        for index in 0..<100 {
            state.record(
                kind: .pageInterceptForwardedToWPS,
                detail: "direction=next,index=\(index)",
                at: start.addingTimeInterval(TimeInterval(index + 2))
            )
        }

        XCTAssertTrue(state.events.contains { $0.kind == .panicModeChanged })
        XCTAssertTrue(state.events.contains { $0.kind == .projectionLost })
        XCTAssertLessThanOrEqual(state.events.count, state.eventLimit)
    }

    func testRepeatedAutomationFailureCoalescesCount() {
        var state = SupportRuntimeState()
        let start = Date(timeIntervalSince1970: 1_790_000_000)

        state.record(kind: .appleScriptFailed, detail: "action=keynote.next-slide,error=failed", at: start)
        state.record(kind: .appleScriptFailed, detail: "action=keynote.next-slide,error=failed", at: start.addingTimeInterval(1))
        state.record(kind: .appleScriptFailed, detail: "action=keynote.next-slide,error=failed", at: start.addingTimeInterval(2))

        let failures = state.events.filter { $0.kind == .appleScriptFailed }
        XCTAssertEqual(failures.count, 1)
        XCTAssertTrue(failures[0].detail.contains("count=3"))
    }

    func testCriticalEventSurvivesEventLimitOverflow() {
        var state = SupportRuntimeState()
        state.eventLimit = 3
        let start = Date(timeIntervalSince1970: 1_790_000_000)

        state.record(kind: .panicModeChanged, detail: "isOn=true", at: start)
        state.record(kind: .systemVolumeSynced, detail: "deviceID=1,volume=0.5", at: start.addingTimeInterval(1))
        state.record(kind: .pageInterceptForwardedToWPS, detail: "direction=next", at: start.addingTimeInterval(2))
        state.record(kind: .mediaRestarted, detail: "source=current", at: start.addingTimeInterval(3))

        XCTAssertTrue(state.events.contains { $0.kind == .panicModeChanged })
        XCTAssertEqual(state.events.count, 3)
    }

    func testLowPriorityEventsAreTrimmedBeforeNormalAndHighEvents() {
        var state = SupportRuntimeState()
        state.eventLimit = 2
        let start = Date(timeIntervalSince1970: 1_790_000_000)

        state.record(kind: .systemVolumeSynced, detail: "deviceID=1,volume=0.5", at: start)
        state.record(kind: .mediaRestarted, detail: "source=current", at: start.addingTimeInterval(1))
        state.record(kind: .pageInterceptDisabled, detail: "reason=eventTapCreateFailed", at: start.addingTimeInterval(2))

        XCTAssertFalse(state.events.contains { $0.kind == .systemVolumeSynced })
        XCTAssertTrue(state.events.contains { $0.kind == .mediaRestarted })
        XCTAssertTrue(state.events.contains { $0.kind == .pageInterceptDisabled })
    }

    func testPriorityTrimmingKeepsRedaction() {
        var state = SupportRuntimeState()

        state.record(
            kind: .appleScriptFailed,
            detail: "action=keynote.open,error=/Users/operator/private.key failed",
            at: Date(timeIntervalSince1970: 1_790_000_000)
        )

        XCTAssertFalse(state.events[0].detail.localizedStandardContains("/Users/"))
        XCTAssertFalse(state.events[0].detail.localizedStandardContains("private.key"))
        XCTAssertTrue(state.events[0].detail.localizedStandardContains("[path redacted]"))
    }
}
