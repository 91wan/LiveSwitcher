import XCTest
@testable import LiveSwitcher

@MainActor
final class PPTRuntimeSupportIngressTests: XCTestCase {
    func testPPTStartSuccessRecordsPageInterceptEnabledAndModeChangedOn() {
        let viewModel = makeViewModel()
        viewModel.pageInterceptSideEffectsEnabled = false

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertEqual(viewModel.supportEvents.filter { $0.kind == .pageInterceptEnabled }.count, 1)
        XCTAssertEqual(viewModel.supportEvents.filter { $0.kind == .pptModeChanged && $0.detail.contains("isOn=true") }.count, 1)
    }

    func testPPTStartFailureDoesNotRecordModeChangedOn() {
        let viewModel = makeViewModel()
        viewModel.pageInterceptStartOverride = { false }

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .pptModeChanged && $0.detail.contains("isOn=true") })
    }

    func testPPTStartFailureRecordsPageInterceptDisabled() {
        let viewModel = makeViewModel()
        viewModel.pageInterceptStartOverride = { false }

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertEqual(viewModel.supportEvents.filter { $0.kind == .pageInterceptDisabled }.count, 1)
    }

    func testPPTStopRecordsModeChangedOff() {
        let viewModel = makeViewModel()
        viewModel.pageInterceptSideEffectsEnabled = false

        viewModel.setPPTMode(true, source: .command)
        viewModel.setPPTMode(false, source: .liveMode)

        XCTAssertEqual(viewModel.supportEvents.filter { $0.kind == .pptModeChanged && $0.detail.contains("isOn=false") }.count, 1)
    }

    func testPPTStopRecordsPageInterceptDisabled() {
        let viewModel = makeViewModel()
        viewModel.pageInterceptSideEffectsEnabled = false

        viewModel.setPPTMode(true, source: .command)
        viewModel.setPPTMode(false, source: .liveMode)

        XCTAssertEqual(viewModel.supportEvents.filter { $0.kind == .pageInterceptDisabled }.count, 1)
    }

    func testDuplicateNoopIntentDoesNotLeakSourceIntoNextSuccessfulToggle() throws {
        let viewModel = makeViewModel()
        viewModel.pageInterceptSideEffectsEnabled = false

        viewModel.setPPTMode(false, source: .command)
        viewModel.setPPTMode(true, source: .liveMode)

        let event = try XCTUnwrap(viewModel.supportEvents.last(where: { $0.kind == .pptModeChanged }))
        XCTAssertTrue(event.detail.contains("isOn=true"))
        XCTAssertTrue(event.detail.contains("source=liveMode"))
        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .pptModeChanged && $0.detail.contains("source=command") })
    }

    func testDuplicatePPTCallbacksDoNotDuplicateSupportEvents() {
        let viewModel = makeViewModel()

        viewModel.dispatchRuntimeFacadeAction(.pptEventTapStarted)
        viewModel.dispatchRuntimeFacadeAction(.pptEventTapStarted)
        viewModel.dispatchRuntimeFacadeAction(.pptEventTapStopped(reason: .operatorDisabled))
        viewModel.dispatchRuntimeFacadeAction(.pptEventTapStopped(reason: .operatorDisabled))

        XCTAssertLessThanOrEqual(viewModel.supportEvents.filter { $0.kind == .pageInterceptEnabled }.count, 1)
        XCTAssertLessThanOrEqual(viewModel.supportEvents.filter { $0.kind == .pageInterceptDisabled }.count, 1)
    }

    func testPPTReducerDoesNotWriteSupportInPPTOwnedMode() {
        [
            reduce(.operatorSetPPTMode(true, source: .liveMode)),
            reduce(.pptEventTapStarted),
            reduce(.pptEventTapFailed(reason: "failed")),
            reduce(.pptEventTapStopped(reason: .operatorDisabled))
        ].forEach { mutation in
            XCTAssertTrue(mutation.state.support.events.isEmpty)
        }
    }

    func testSupportEventRecordedStillWritesRuntimeSupportStorage() {
        let event = LiveSupportEvent(
            timestamp: Date(timeIntervalSince1970: 100),
            kind: .pageInterceptEnabled,
            detail: "state=enabled"
        )

        let mutation = reduce(.supportEventRecorded(event))

        XCTAssertEqual(mutation.state.support.events, [event])
    }

    private func reduce(_ action: LiveRuntimeAction) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: action,
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100), bridgeMode: .pptOwned)
        )
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "PPTRuntimeSupportIngressTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults
        )
    }
}
