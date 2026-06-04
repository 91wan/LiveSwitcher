import XCTest
@testable import LiveSwitcher

@MainActor
final class AutomationNoticeRuntimeSupportBoundaryTests: XCTestCase {
    func testAutomationNoticeOwnedReducerDoesNotWriteAppleScriptFailedSupport() {
        let mutation = reduce(.automationFailed(action: "keynote.next-slide", sanitizedMessage: "failed"))

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testAutomationFailedReducerDoesNotWriteSupportInAutomationNoticeOwned() {
        let mutation = reduce(.automationFailed(action: "keynote.next-slide", sanitizedMessage: "failed"))

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testAutomationNoticeOwnedReducerDoesNotWriteProgramSourceMissingSupport() {
        let mutation = reduce(.automationNoticeRequested(action: "program.source.missing"))

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testSupportEventRecordedStillWritesRuntimeSupportStorage() throws {
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 200),
            kind: .appleScriptFailed,
            detail: "action=keynote.next-slide,error=failed"
        )

        let mutation = reduce(.supportEventRecorded(event))

        let recorded = try XCTUnwrap(mutation.state.support.events.first)
        XCTAssertEqual(recorded.kind, .appleScriptFailed)
        XCTAssertTrue(recorded.detail.contains("action=keynote.next-slide"))
    }

    func testViewModelRecordsAppleScriptFailureSupport() {
        let viewModel = makeViewModel()

        viewModel.handleAppleScriptFailure(
            AppleScriptError.executionFailed(action: "keynote.next-slide", message: "failed"),
            action: "keynote.next-slide"
        )

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .appleScriptFailed })
    }

    func testHandleAppleScriptFailureWritesSupportThroughViewModelOnly() {
        let viewModel = makeViewModel()

        viewModel.handleAppleScriptFailure(
            AppleScriptError.executionFailed(action: "keynote.next-slide", message: "failed"),
            action: "keynote.next-slide"
        )

        XCTAssertEqual(viewModel.supportEvents.filter { $0.kind == .appleScriptFailed }.count, 1)
        XCTAssertEqual(viewModel.runtime.state.support.events.filter { $0.kind == .appleScriptFailed }.count, 1)
        XCTAssertEqual(viewModel.runtime.actionLog.filter { $0.actionName == "supportEventRecorded" }.count, 1)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "automationFailed" })
    }

    func testRepeatedAppleScriptFailuresCoalesceSupportEvents() {
        let viewModel = makeViewModel()

        viewModel.handleAppleScriptFailure(
            AppleScriptError.executionFailed(action: "keynote.next-slide", message: "failed"),
            action: "keynote.next-slide"
        )
        viewModel.handleAppleScriptFailure(
            AppleScriptError.executionFailed(action: "keynote.next-slide", message: "failed"),
            action: "keynote.next-slide"
        )

        let failures = viewModel.supportEvents.filter { $0.kind == .appleScriptFailed }
        XCTAssertEqual(failures.count, 1)
        XCTAssertTrue(failures[0].detail.contains("count=2"))
    }

    func testRepeatedAppleScriptFailuresCoalesceSupportButSuppressVisibleNotice() throws {
        let viewModel = makeViewModel()

        viewModel.handleAppleScriptFailure(
            AppleScriptError.executionFailed(action: "keynote.next-slide", message: "failed"),
            action: "keynote.next-slide"
        )
        let firstNotice = try XCTUnwrap(viewModel.automationRuntimeNotice)
        let firstShowCount = viewModel.runtime.recordedEffects.filter { effect in
            if case .showAutomationNotice = effect { return true }
            return false
        }.count

        viewModel.handleAppleScriptFailure(
            AppleScriptError.executionFailed(action: "keynote.next-slide", message: "failed"),
            action: "keynote.next-slide"
        )

        let failures = viewModel.supportEvents.filter { $0.kind == .appleScriptFailed }
        let secondShowCount = viewModel.runtime.recordedEffects.filter { effect in
            if case .showAutomationNotice = effect { return true }
            return false
        }.count

        XCTAssertEqual(viewModel.automationRuntimeNotice, firstNotice)
        XCTAssertEqual(failures.count, 1)
        XCTAssertTrue(failures[0].detail.contains("count=2"))
        XCTAssertEqual(secondShowCount, firstShowCount)
    }

    func testRepeatedAppleScriptFailuresDoNotEvictCriticalSupportEvents() {
        var state = SupportRuntimeState()
        state.eventLimit = 8
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        state.record(kind: .panicModeChanged, detail: "isOn=true", at: start)
        state.record(kind: .projectionLost, detail: "externalDisplay=false", at: start.addingTimeInterval(1))

        for index in 0..<100 {
            state.record(
                kind: .appleScriptFailed,
                detail: "action=keynote.next-slide,error=failed-\(index)",
                at: start.addingTimeInterval(TimeInterval(index + 2))
            )
        }

        XCTAssertTrue(state.events.contains { $0.kind == .panicModeChanged })
        XCTAssertTrue(state.events.contains { $0.kind == .projectionLost })
        XCTAssertLessThanOrEqual(state.events.count, state.eventLimit)
    }

    func testCriticalSupportEventsSurviveRepeatedAutomationFailures() {
        testRepeatedAppleScriptFailuresDoNotEvictCriticalSupportEvents()
    }

    private func reduce(_ action: LiveRuntimeAction) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: action,
            environment: .productionAutomationNoticeOwning(now: Date(timeIntervalSince1970: 100))
        )
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "AutomationNoticeRuntimeSupportBoundaryTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults
        )
    }
}
