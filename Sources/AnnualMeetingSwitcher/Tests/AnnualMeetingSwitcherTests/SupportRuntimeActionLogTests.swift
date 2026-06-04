import XCTest
@testable import LiveSwitcher

@MainActor
final class SupportRuntimeActionLogTests: XCTestCase {
    func testSupportEventRecordedIsNotLogged() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .supportOwned)
        )
        let event = supportEvent()

        runtime.dispatch(.supportEventRecorded(event))

        XCTAssertFalse(runtime.actionLog.contains { $0.actionName == "supportEventRecorded" })
    }

    func testSupportEventRecordedStillWritesSupportState() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .supportOwned)
        )
        let event = supportEvent()

        runtime.dispatch(.supportEventRecorded(event))

        XCTAssertEqual(runtime.state.support.events, [event])
    }

    func testRepeatedSupportEventsDoNotGrowActionLog() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .supportOwned)
        )

        runtime.dispatch(.supportEventRecorded(supportEvent(timestamp: 100)))
        runtime.dispatch(.supportEventRecorded(supportEvent(timestamp: 101)))
        runtime.dispatch(.supportEventRecorded(supportEvent(timestamp: 102)))

        XCTAssertFalse(runtime.actionLog.contains { $0.actionName == "supportEventRecorded" })
        XCTAssertEqual(runtime.state.support.events.count, 3)
    }

    func testAutomationFailedStillLogsAction() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        viewModel.handleAppleScriptFailure(
            AppleScriptError.executionFailed(action: "keynote.next-slide", message: "failed"),
            action: "keynote.next-slide"
        )

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "automationFailed" })
    }

    func testOperatorProjectionToggleStillLogsAction() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .projectionOwned)
        )
        var state = runtime.state
        state.projection.hasExternalDisplay = true
        runtime.replaceStateForFacadeSync(state, clearActionLog: false)

        runtime.dispatch(.operatorToggledProjection)

        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "operatorToggledProjection" })
    }

    func testAutomationNoticeDismissedStillLogsAction() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .automationNoticeOwned)
        )

        runtime.dispatch(.automationNoticeDismissed)

        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "automationNoticeDismissed" })
    }

    func testViewModelSupportEventIngressDoesNotAddOperatorActionLogEntry() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        viewModel.recordSupportEvent(
            kind: .projectionStarted,
            detail: "source=viewModel",
            timestamp: Date(timeIntervalSince1970: 100)
        )

        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "supportEventRecorded" })
        XCTAssertEqual(viewModel.supportEvents, viewModel.runtime.state.support.events)
        XCTAssertEqual(viewModel.supportEvents.count, 1)
    }

    func testAutomationFailedStillAddsOperatorActionLogEntry() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        viewModel.handleAppleScriptFailure(
            AppleScriptError.executionFailed(action: "keynote.next-slide", message: "failed"),
            action: "keynote.next-slide"
        )

        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "supportEventRecorded" })
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "automationFailed" })
    }

    func testProjectionToggleStillAddsOperatorActionLogEntry() {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .projectionOwned)
        )
        var state = runtime.state
        state.projection.hasExternalDisplay = true
        runtime.replaceStateForFacadeSync(state, clearActionLog: false)

        runtime.dispatch(.operatorToggledProjection)

        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "operatorToggledProjection" })
    }

    private func supportEvent(timestamp: TimeInterval = 100) -> LiveSupportEvent {
        LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: timestamp),
            kind: .projectionStarted,
            detail: "source=viewModel"
        )
    }
}
