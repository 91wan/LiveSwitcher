import AppKit
import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelRuntimeFacadeSyncPruningTests: XCTestCase {
    func testProjectionOutputDoesNotManuallySyncProjectionAfterToggleDispatch() throws {
        let body = try functionBody(named: "handleBroadcastToggle", in: projectionOutputSource())

        XCTAssertTrue(body.contains("dispatchRuntimeFacadeAction(.operatorToggledProjection)"))
        XCTAssertFalse(body.contains("syncProjectionFacadeFromRuntime()"))
    }

    func testProjectionOutputDoesNotManuallySyncProjectionAfterStartFailureDispatch() throws {
        let body = try functionBody(named: "showOutputWindowFromRuntimeProjection", in: projectionOutputSource())
        let failureBlock = try XCTUnwrap(body.slice(
            from: "dispatchRuntimeFacadeAction(.projectionStartFailed",
            to: "recordProjectionSupportAfterRuntimeStartFailure"
        ))

        XCTAssertFalse(failureBlock.contains("syncProjectionFacadeFromRuntime()"))
    }

    func testProjectionOutputDoesNotManuallySyncProjectionAfterDisplayLostDispatch() throws {
        let body = try functionBody(named: "handleExternalDisplayLost", in: projectionOutputSource())

        XCTAssertTrue(body.contains("dispatchRuntimeFacadeAction(.projectionExternalDisplayLost)"))
        XCTAssertFalse(body.contains("syncProjectionFacadeFromRuntime()"))
    }

    func testProjectionOutputReliesOnRuntimeFacadeSyncPolicyForProjectionActions() {
        let actions: [LiveRuntimeAction] = [
            LiveRuntimeAction.operatorToggledProjection,
            .projectionStartFailed(reason: .noTargetScreen),
            .projectionExternalDisplayLost
        ]
        actions.forEach { action in
            XCTAssertTrue(LiveRuntimeFacadeSyncPolicy.options(for: action).syncProjection)
        }
    }

    func testPPTModeDoesNotManuallySyncPPTAfterIntentDispatch() throws {
        let body = try functionBody(named: "dispatchPPTIntent", in: pptModeSource())

        XCTAssertTrue(body.contains("dispatchRuntimeFacadeAction(action)"))
        XCTAssertFalse(body.contains("syncPPTFacadeFromRuntime()"))
    }

    func testPPTEventTapDoesNotManuallySyncPPTAfterStartedDispatch() throws {
        let body = try functionBody(named: "completePPTEventTapStartFromRuntime", in: pptEventTapSource())

        XCTAssertTrue(body.contains("dispatchRuntimeFacadeAction(.pptEventTapStarted)"))
        XCTAssertFalse(body.contains("syncPPTFacadeFromRuntime()"))
    }

    func testPPTEventTapDoesNotManuallySyncPPTAfterFailedDispatch() throws {
        let body = try functionBody(named: "completePPTEventTapStartFailureFromRuntime", in: pptEventTapSource())

        XCTAssertTrue(body.contains("dispatchRuntimeFacadeAction(.pptEventTapFailed(reason: reason))"))
        XCTAssertFalse(body.contains("syncPPTFacadeFromRuntime()"))
    }

    func testPPTEventTapDoesNotManuallySyncPPTAfterStoppedDispatch() throws {
        let body = try functionBody(named: "completePPTEventTapStopFromRuntime", in: pptEventTapSource())

        XCTAssertTrue(body.contains("dispatchRuntimeFacadeAction(.pptEventTapStopped(reason: reason))"))
        XCTAssertFalse(body.contains("syncPPTFacadeFromRuntime()"))
    }

    func testPPTModeReliesOnRuntimeFacadeSyncPolicyForPPTActions() {
        let actions: [LiveRuntimeAction] = [
            LiveRuntimeAction.operatorSetPPTMode(true, source: .liveMode),
            .operatorToggledPPTMode(source: .command),
            .pptEventTapStarted,
            .pptEventTapFailed(reason: "accessibilityPermission"),
            .pptEventTapStopped(reason: .operatorDisabled)
        ]
        actions.forEach { action in
            XCTAssertTrue(LiveRuntimeFacadeSyncPolicy.options(for: action).syncPPT)
        }
    }

    func testProjectionActionsStillSyncProjectionFacadeThroughPolicy() {
        let actions: [LiveRuntimeAction] = [
            LiveRuntimeAction.operatorToggledProjection,
            .projectionStartFailed(reason: .noTargetScreen),
            .projectionExternalDisplayLost,
            .projectionExternalDisplayAvailable,
            .projectionExternalDisplayUnavailable
        ]
        actions.forEach { action in
            let options = LiveRuntimeFacadeSyncPolicy.options(for: action)
            XCTAssertTrue(options.syncProjection, "\(action)")
        }
    }

    func testPPTActionsStillSyncPPTFacadeThroughPolicy() {
        let actions: [LiveRuntimeAction] = [
            LiveRuntimeAction.operatorSetPPTMode(true, source: .liveMode),
            .operatorToggledPPTMode(source: .command),
            .pptEventTapStarted,
            .pptEventTapFailed(reason: "accessibilityPermission"),
            .pptEventTapStopped(reason: .operatorDisabled)
        ]
        actions.forEach { action in
            let options = LiveRuntimeFacadeSyncPolicy.options(for: action)
            XCTAssertTrue(options.syncPPT, "\(action)")
        }
    }

    func testProjectionActionsDoNotSyncPPTFacade() {
        let actions: [LiveRuntimeAction] = [
            LiveRuntimeAction.operatorToggledProjection,
            .projectionStartFailed(reason: .noTargetScreen),
            .projectionExternalDisplayLost,
            .projectionExternalDisplayAvailable,
            .projectionExternalDisplayUnavailable
        ]
        actions.forEach { action in
            XCTAssertFalse(LiveRuntimeFacadeSyncPolicy.options(for: action).syncPPT)
        }
    }

    func testPPTActionsDoNotSyncProjectionFacade() {
        let actions: [LiveRuntimeAction] = [
            LiveRuntimeAction.operatorSetPPTMode(true, source: .liveMode),
            .operatorToggledPPTMode(source: .command),
            .pptEventTapStarted,
            .pptEventTapFailed(reason: "accessibilityPermission"),
            .pptEventTapStopped(reason: .operatorDisabled)
        ]
        actions.forEach { action in
            XCTAssertFalse(LiveRuntimeFacadeSyncPolicy.options(for: action).syncProjection)
        }
    }

    func testProjectionAndPPTActionsDoNotDispatchAudioInputs() {
        let actions: [LiveRuntimeAction] = [
            .operatorSetPPTMode(true, source: .liveMode),
            .operatorToggledPPTMode(source: .command),
            .pptEventTapStarted,
            .pptEventTapFailed(reason: "accessibilityPermission"),
            .pptEventTapStopped(reason: .operatorDisabled)
        ]
        actions.forEach { action in
            XCTAssertFalse(LiveRuntimeFacadeSyncPolicy.options(for: action).dispatchAudioInputsChanged)
        }
    }

    func testHandleBroadcastToggleStillSyncsProjectionFacade() throws {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .panicOwned)
        viewModel.externalScreenProvider = { screen }

        viewModel.handleBroadcastToggle()

        XCTAssertTrue(viewModel.runtime.state.projection.isBroadcasting)
        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertTrue(viewModel.isExternalDisplayAvailable)
    }

    func testShowOutputWindowStartFailureStillSyncsProjectionFacade() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .panicOwned)
        viewModel.externalScreenProvider = { nil }
        viewModel.updateExternalDisplayAvailabilityForProjection(true)

        viewModel.showOutputWindowFromRuntimeProjection()

        XCTAssertFalse(viewModel.runtime.state.projection.hasExternalDisplay)
        XCTAssertFalse(viewModel.isExternalDisplayAvailable)
        XCTAssertEqual(viewModel.broadcastSafetyNotice, "未检测到外接屏幕，未开始投射")
    }

    func testHandleExternalDisplayLostStillSyncsProjectionFacade() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true
        state.projection.isBroadcasting = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .panicOwned)
        viewModel.updateExternalDisplayAvailabilityForProjection(true)
        viewModel.isBroadcasting = true

        viewModel.handleExternalDisplayLost()

        XCTAssertFalse(viewModel.runtime.state.projection.hasExternalDisplay)
        XCTAssertFalse(viewModel.runtime.state.projection.isBroadcasting)
        XCTAssertFalse(viewModel.isExternalDisplayAvailable)
        XCTAssertFalse(viewModel.isBroadcasting)
    }

    func testProjectionSupportEventsStillRecordedAfterToggle() throws {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("No NSScreen is available in this test environment.")
        }
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .panicOwned)
        viewModel.externalScreenProvider = { screen }

        viewModel.handleBroadcastToggle()

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionStarted })
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionToggle })
    }

    func testProjectionToggleSupportEventsStillRecorded() throws {
        try testProjectionSupportEventsStillRecordedAfterToggle()
    }

    func testProjectionStartFailureSupportEventsStillRecorded() {
        let viewModel = makeProductionViewModel()
        viewModel.externalScreenProvider = { nil }
        viewModel.refreshExternalDisplayAvailability()

        viewModel.handleBroadcastToggle()

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionFailClosed })
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionStartFailed })
    }

    func testProjectionSupportEventsStillRecordedAfterDisplayLost() {
        var state = LiveRuntimeState()
        state.projection.hasExternalDisplay = true
        state.projection.isBroadcasting = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .panicOwned)

        viewModel.handleExternalDisplayLost()

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionFailClosed })
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .projectionLost })
    }

    func testProjectionDisplayLostSupportEventsStillRecorded() {
        testProjectionSupportEventsStillRecordedAfterDisplayLost()
    }

    func testSetPPTModeTrueStillKeepsFacadeEnabledWhileStartPending() {
        let viewModel = makeViewModel(runtimeState: LiveRuntimeState(), bridgeMode: .pptOwned)

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertTrue(viewModel.runtime.state.ppt.isRequested)
        XCTAssertFalse(viewModel.runtime.state.ppt.isEventTapActive)
        XCTAssertTrue(viewModel.isPageInterceptEnabled)
    }

    func testTogglePPTModeOnStillKeepsFacadeEnabledWhileStartPending() {
        let viewModel = makeViewModel(runtimeState: LiveRuntimeState(), bridgeMode: .pptOwned)

        viewModel.togglePPTMode(source: .liveMode)

        XCTAssertTrue(viewModel.runtime.state.ppt.isRequested)
        XCTAssertFalse(viewModel.runtime.state.ppt.isEventTapActive)
        XCTAssertTrue(viewModel.isPageInterceptEnabled)
    }

    func testPPTEventTapStartedStillSyncsFacadeTrue() {
        let viewModel = makeProductionViewModel()
        viewModel.pageInterceptSideEffectsEnabled = false

        viewModel.setPPTMode(true, source: .liveMode)
        viewModel.startPPTEventTapFromRuntime()

        XCTAssertTrue(viewModel.runtime.state.ppt.isEventTapActive)
        XCTAssertTrue(viewModel.isPageInterceptEnabled)
    }

    func testPPTEventTapFailedStillSyncsFacadeFalse() {
        let viewModel = makeProductionViewModel()
        viewModel.testHooks.pageInterceptStartOverride = { false }

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertFalse(viewModel.runtime.state.ppt.isRequested)
        XCTAssertFalse(viewModel.runtime.state.ppt.isEventTapActive)
        XCTAssertFalse(viewModel.isPageInterceptEnabled)
    }

    func testPPTEventTapStoppedStillSyncsFacadeFalse() {
        let viewModel = makeProductionViewModel()
        viewModel.pageInterceptSideEffectsEnabled = false

        viewModel.setPPTMode(true, source: .liveMode)
        viewModel.setPPTMode(false, source: .liveMode)

        XCTAssertFalse(viewModel.runtime.state.ppt.isRequested)
        XCTAssertFalse(viewModel.runtime.state.ppt.isEventTapActive)
        XCTAssertFalse(viewModel.isPageInterceptEnabled)
    }

    func testPPTEventTapFailureStillRecordsSupportEvent() {
        let viewModel = makeProductionViewModel()
        viewModel.testHooks.pageInterceptStartOverride = { false }

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .pageInterceptDisabled })
    }

    func testPPTEnableSuccessStillRecordsPPTModeChangedOnce() {
        let viewModel = makeProductionViewModel()
        viewModel.testHooks.pageInterceptStartOverride = { true }

        viewModel.setPPTMode(true, source: .liveMode)

        let successEvents = viewModel.supportEvents.filter { $0.kind == .pptModeChanged }
        XCTAssertEqual(successEvents.count, 1)
        XCTAssertTrue(successEvents[0].detail.contains("isOn=true"))
    }

    func testPPTEnableFailureStillRecordsFailureButNoSuccessEvent() {
        let viewModel = makeProductionViewModel()
        viewModel.testHooks.pageInterceptStartOverride = { false }

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .pageInterceptDisabled })
        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .pptModeChanged && $0.detail.contains("isOn=true") })
    }

    func testPPTDisableStillRecordsSource() throws {
        let viewModel = makeProductionViewModel()
        viewModel.pageInterceptSideEffectsEnabled = false

        viewModel.setPPTMode(true, source: .command)
        viewModel.setPPTMode(false, source: .liveMode)

        let event = try XCTUnwrap(viewModel.supportEvents.last(where: { $0.kind == .pptModeChanged }))
        XCTAssertTrue(event.detail.contains("isOn=false"))
        XCTAssertTrue(event.detail.contains("source=liveMode"))
    }

    func testPPTEventTapStartedStillRecordsPPTModeChangedForPendingSource() {
        testPPTEnableSuccessStillRecordsPPTModeChangedOnce()
    }

    func testPPTEventTapStoppedStillRecordsPPTModeChangedForPendingSource() throws {
        try testPPTDisableStillRecordsSource()
    }

    func testPendingPPTToggleSourceStillConsumedAfterSuccess() {
        let viewModel = makeProductionViewModel()
        viewModel.testHooks.pageInterceptStartOverride = { true }

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertNil(viewModel.currentPendingPPTToggleSource())
    }

    func testPendingPPTToggleSourceStillClearedAfterFailure() {
        let viewModel = makeProductionViewModel()
        viewModel.testHooks.pageInterceptStartOverride = { false }

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertNil(viewModel.currentPendingPPTToggleSource())
    }

    func testNoManualFacadeSyncBridgeModeDomainOrPortAdded() throws {
        let stateSource = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeState.swift")
        let portSource = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeEffectPortKind.swift")

        XCTAssertFalse(stateSource.contains("manualFacadeSyncOwned"))
        XCTAssertFalse(stateSource.contains("doubleSyncOwned"))
        XCTAssertFalse(portSource.contains("manualFacadeSync"))
        XCTAssertFalse(portSource.contains("doubleSync"))
    }

    private func makeViewModel(
        runtimeState: LiveRuntimeState,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> SwitcherViewModel {
        let suiteName = "ViewModelRuntimeFacadeSyncPruningTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let runtime = LiveRuntimeStore(
            initialState: runtimeState,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults,
            runtime: runtime
        )
    }

    private func makeProductionViewModel() -> SwitcherViewModel {
        let suiteName = "ViewModelRuntimeFacadeSyncPruningTests.production.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults
        )
    }

    private func projectionOutputSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProjectionOutput.swift")
    }

    private func pptModeSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PPTMode.swift")
    }

    private func pptEventTapSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PPTEventTap.swift")
    }

    private func functionBody(named name: String, in source: String) throws -> String {
        guard let body = source.extractedRuntimeFunctionBody(named: name) else {
            XCTFail("Missing function \(name)")
            return ""
        }
        return body
    }
}
