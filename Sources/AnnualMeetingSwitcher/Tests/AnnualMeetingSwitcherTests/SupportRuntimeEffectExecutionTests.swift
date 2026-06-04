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
