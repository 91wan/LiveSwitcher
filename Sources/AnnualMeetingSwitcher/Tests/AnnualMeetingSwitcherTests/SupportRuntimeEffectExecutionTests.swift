import XCTest
@testable import LiveSwitcher

@MainActor
final class SupportRuntimeEffectExecutionTests: XCTestCase {
    func testSupportPortRunsForRecordSupportEffect() {
        let port = SupportEventPortSpy()
        let event = supportEvent()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, support: port)

        runner.run([.recordSupportEvent(event)], currentState: { LiveRuntimeState() }, dispatch: { _ in })

        XCTAssertEqual(port.events, [event])
    }

    func testProductionSupportPortSyncsFacadeFromRuntime() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        viewModel.recordSupportEvent(
            kind: .projectionStarted,
            detail: "isBroadcasting=true",
            timestamp: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(viewModel.supportEvents, viewModel.runtime.state.support.events)
    }

    func testSupportPortDoesNotAppendDuplicateEvent() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        viewModel.recordSupportEvent(
            kind: .pageInterceptEnabled,
            detail: "state=enabled",
            timestamp: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(viewModel.runtime.state.support.events.count, 1)
        XCTAssertEqual(viewModel.supportEvents.count, 1)
    }

    func testSupportPortDoesNotApplyRedactionOrCoalescingAgain() throws {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        for offset in 0..<2 {
            viewModel.recordSupportEvent(
                kind: .appleScriptFailed,
                detail: "action=keynote.open,error=/Users/operator/private.key failed",
                timestamp: Date(timeIntervalSince1970: TimeInterval(100 + offset))
            )
        }

        let event = try XCTUnwrap(viewModel.supportEvents.first)
        XCTAssertEqual(viewModel.supportEvents.count, 1)
        XCTAssertEqual(viewModel.runtime.state.support.events.count, 1)
        XCTAssertTrue(event.detail.contains("count=2"))
        XCTAssertFalse(event.detail.localizedStandardContains("/Users/"))
        XCTAssertFalse(event.detail.localizedStandardContains("private.key"))
    }

    func testSupportPortDoesNotRunAutomation() {
        let support = SupportEventPortSpy()
        let automation = AutomationPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, automation: automation, support: support)
        let event = supportEvent()

        runner.run([.recordSupportEvent(event)], currentState: { LiveRuntimeState() }, dispatch: { _ in })

        XCTAssertEqual(support.events, [event])
        XCTAssertTrue(automation.actions.isEmpty)
    }

    func testSupportPortReceivesAcceptedSanitizedEvent() throws {
        let support = SupportEventPortSpy()
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, support: support),
            environment: .productionSupportOwning()
        )

        runtime.dispatch(.supportEventRecorded(LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .appleScriptFailed,
            detail: "path=/Users/operator/private-show.key,error=failed"
        )))

        let accepted = try XCTUnwrap(support.events.last)
        XCTAssertEqual(accepted, runtime.state.support.events.last)
        XCTAssertFalse(accepted.detail.localizedStandardContains("/Users/"))
        XCTAssertFalse(accepted.detail.localizedStandardContains("private-show.key"))
    }

    func testSupportPortDoesNotReceiveRawInputEvent() throws {
        let support = SupportEventPortSpy()
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, support: support),
            environment: .productionSupportOwning()
        )
        let first = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .appleScriptFailed,
            detail: "action=keynote.open,error=failed"
        )
        let rawRepeat = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 101),
            kind: .appleScriptFailed,
            detail: "action=keynote.open,error=failed"
        )

        runtime.dispatch(.supportEventRecorded(first))
        runtime.dispatch(.supportEventRecorded(rawRepeat))

        let accepted = try XCTUnwrap(support.events.last)
        XCTAssertNotEqual(accepted, rawRepeat)
        XCTAssertTrue(accepted.detail.contains("count=2"))
    }

    func testSupportPortReceivesAcceptedCoalescedEventOnRepeatedFailure() throws {
        let support = SupportEventPortSpy()
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, support: support),
            environment: .productionSupportOwning()
        )
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

        runtime.dispatch(.supportEventRecorded(first))
        runtime.dispatch(.supportEventRecorded(second))

        let accepted = try XCTUnwrap(runtime.state.support.events.first)
        XCTAssertEqual(support.events.last, accepted)
        XCTAssertTrue(accepted.detail.contains("count=2"))
        XCTAssertNotEqual(support.events.last, second)
    }

    func testSupportPortDoesNotReceiveTrimmedLowPriorityEvent() {
        let support = SupportEventPortSpy()
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, support: support),
            environment: .productionSupportOwning()
        )
        var state = runtime.state
        state.support.eventLimit = 1
        state.support.record(kind: .panicModeChanged, detail: "isOn=true", at: Date(timeIntervalSince1970: 100))
        runtime.replaceStateForFacadeSync(state, clearActionLog: false)

        runtime.dispatch(.supportEventRecorded(LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 101),
            kind: .systemVolumeSynced,
            detail: "deviceID=1,volume=0.5"
        )))

        XCTAssertTrue(support.events.isEmpty)
        XCTAssertEqual(runtime.state.support.events.map(\.kind), [.panicModeChanged])
    }

    private func supportEvent() -> LiveSupportEvent {
        LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .pageInterceptEnabled,
            detail: "state=enabled"
        )
    }
}

private final class SupportEventPortSpy: SupportEventPort {
    private(set) var events: [LiveSupportEvent] = []

    func record(_ event: LiveSupportEvent) {
        events.append(event)
    }
}

private final class AutomationPortSpy: AutomationPort {
    private(set) var actions: [String] = []

    func run(script: String, action: String) {
        actions.append(action)
    }
}
