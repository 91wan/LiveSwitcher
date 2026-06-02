import XCTest
@testable import LiveSwitcher

@MainActor
final class PPTMirrorTests: XCTestCase {
    func testOperatorToggledPPTModeInAudioOwnedDoesNotChangePPTState() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        state.ppt.isEventTapActive = true
        state.ppt.lastFailureReason = "existing"
        let originalPPT = state.ppt

        let mutation = reduce(state, .operatorToggledPPTMode(source: .liveMode), bridgeMode: .audioOwned)

        XCTAssertEqual(mutation.state.ppt, originalPPT)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testPPTEventTapStartedUpdatesMirror() {
        let mutation = reduce(LiveRuntimeState(), .pptEventTapStarted, bridgeMode: .audioOwned)

        XCTAssertTrue(mutation.state.ppt.isRequested)
        XCTAssertTrue(mutation.state.ppt.isEventTapActive)
        XCTAssertNil(mutation.state.ppt.lastFailureReason)
    }

    func testPPTEventTapFailedUpdatesMirror() {
        let mutation = reduce(LiveRuntimeState(), .pptEventTapFailed(reason: "permissionDenied"), bridgeMode: .audioOwned)

        XCTAssertFalse(mutation.state.ppt.isRequested)
        XCTAssertFalse(mutation.state.ppt.isEventTapActive)
        XCTAssertEqual(mutation.state.ppt.lastFailureReason, "permissionDenied")
    }

    func testPPTEventTapStoppedUpdatesMirror() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        state.ppt.isEventTapActive = true

        let mutation = reduce(state, .pptEventTapStopped(reason: .operatorDisabled), bridgeMode: .audioOwned)

        XCTAssertFalse(mutation.state.ppt.isRequested)
        XCTAssertFalse(mutation.state.ppt.isEventTapActive)
    }

    func testViewModelFailureDoesNotRecordSuccess() {
        let viewModel = makeViewModel()
        viewModel.pageInterceptStartOverride = { false }

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .pageInterceptDisabled })
        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .pptModeChanged })
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "PPTMirrorTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults
        )
    }
}
