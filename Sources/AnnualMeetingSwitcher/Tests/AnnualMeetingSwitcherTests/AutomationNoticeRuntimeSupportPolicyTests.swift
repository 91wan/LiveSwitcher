import XCTest
@testable import LiveSwitcher

@MainActor
final class AutomationNoticeRuntimeSupportPolicyTests: XCTestCase {
    func testAutomationFailedStillSyncsAutomationNoticeFacadeThroughPolicy() {
        let options = LiveRuntimeFacadeSyncPolicy.options(for: .automationFailed(
            action: "keynote.next-slide",
            sanitizedMessage: "failed"
        ))

        XCTAssertTrue(options.syncAutomationNotice)
    }

    func testAutomationFailedAlsoSyncsSupportFacadeThroughPolicy() {
        let options = LiveRuntimeFacadeSyncPolicy.options(for: .automationFailed(
            action: "keynote.next-slide",
            sanitizedMessage: "failed"
        ))

        XCTAssertTrue(options.syncSupport)
    }

    func testAutomationNoticeRequestedDoesNotSyncSupportFacade() {
        XCTAssertFalse(
            LiveRuntimeFacadeSyncPolicy.options(for: .automationNoticeRequested(action: "keynote.next-slide")).syncSupport
        )
    }

    func testAutomationNoticeExpiredDoesNotSyncSupportFacade() {
        XCTAssertFalse(LiveRuntimeFacadeSyncPolicy.options(for: .automationNoticeExpired(UUID())).syncSupport)
    }

    func testAutomationNoticeDismissedDoesNotSyncSupportFacade() {
        XCTAssertFalse(LiveRuntimeFacadeSyncPolicy.options(for: .automationNoticeDismissed).syncSupport)
    }

    func testAutomationFailedSupportSyncNoopsBeforeSupportOwnership() {
        let viewModel = makeViewModel(bridgeMode: .automationNoticeOwned)
        let existing = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 1),
            kind: .projectionStarted,
            detail: "source=facade"
        )
        viewModel.applySupportEventsProjectionFromRuntime([existing])

        viewModel.dispatchRuntimeFacadeAction(.automationFailed(
            action: "keynote.next-slide",
            sanitizedMessage: "failed"
        ))

        XCTAssertEqual(viewModel.supportEvents, [existing])
    }

    func testAutomationFailedSupportSyncProjectsReducerSupportWhenFullRuntime() {
        let viewModel = makeViewModel(bridgeMode: .fullRuntime)

        viewModel.dispatchRuntimeFacadeAction(.automationFailed(
            action: "keynote.next-slide",
            sanitizedMessage: "failed"
        ))

        XCTAssertEqual(viewModel.supportEvents.map(\.kind), [.appleScriptFailed])
    }

    func testAutomationFailedWritesSupportOnlyWhenReducerSupportAllowed() {
        let mutation = reduce(
            .automationFailed(action: "keynote.next-slide", sanitizedMessage: "failed"),
            environment: .fullRuntimeForTests(now: now)
        )

        XCTAssertEqual(mutation.state.support.events.map(\.kind), [.appleScriptFailed])
    }

    func testAutomationFailedDoesNotWriteSupportInProductionPanicOwned() {
        let mutation = reduce(
            .automationFailed(action: "keynote.next-slide", sanitizedMessage: "failed"),
            environment: .productionPanicOwning(now: now)
        )

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testAutomationNoticeRequestedDoesNotWriteSupport() {
        let mutation = reduce(.automationNoticeRequested(action: "keynote.next-slide"))

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testAutomationNoticeExpiredDoesNotWriteSupport() {
        let notice = AutomationRuntimeNoticePolicy.make(action: "keynote.next-slide")
        var state = LiveRuntimeState()
        state.automation.notice = notice

        let mutation = reduce(state, .automationNoticeExpired(notice.id))

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testAutomationNoticeDismissedDoesNotWriteSupport() {
        var state = LiveRuntimeState()
        state.automation.notice = AutomationRuntimeNoticePolicy.make(action: "keynote.next-slide")

        let mutation = reduce(state, .automationNoticeDismissed)

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testSupportEventRecordedStillDoesNotPolluteActionLog() {
        let runtime = LiveRuntimeStore(environment: .productionSupportOwning(now: now))

        runtime.dispatch(.supportEventRecorded(LiveSupportEvent(timestamp: now, kind: .appleScriptFailed, detail: "failed")))

        XCTAssertTrue(runtime.actionLog.isEmpty)
        XCTAssertEqual(runtime.state.support.events.map(\.kind), [.appleScriptFailed])
    }

    private func reduce(
        _ action: LiveRuntimeAction,
        environment: LiveRuntimeEnvironment = .productionAutomationNoticeOwning(now: Date(timeIntervalSince1970: 100))
    ) -> LiveRuntimeMutation {
        reduce(LiveRuntimeState(), action, environment: environment)
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction,
        environment: LiveRuntimeEnvironment = .productionAutomationNoticeOwning(now: Date(timeIntervalSince1970: 100))
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(state: state, action: action, environment: environment)
    }

    private let now = Date(timeIntervalSince1970: 100)

    private func makeViewModel(bridgeMode: LiveRuntimeBridgeMode) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(now: now, bridgeMode: bridgeMode)
        )
        let suiteName = "AutomationNoticeRuntimeSupportPolicyTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults,
            runtime: runtime
        )
    }
}
