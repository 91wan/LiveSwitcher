import XCTest
@testable import LiveSwitcher

@MainActor
final class PPTModeOwnershipTests: XCTestCase {
    func testAudioOwnedOperatorToggleDoesNotMutatePPTState() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        state.ppt.isEventTapActive = true
        state.ppt.lastFailureReason = "existing"
        let originalPPT = state.ppt

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorToggledPPTMode(source: .liveMode),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )

        XCTAssertEqual(mutation.state.ppt, originalPPT)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testAudioOwnedPPTCallbacksDoNotMutatePPTState() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        state.ppt.isEventTapActive = false
        state.ppt.lastFailureReason = "existing"
        let originalPPT = state.ppt

        let started = LiveRuntimeReducer.reduce(
            state: state,
            action: .pptEventTapStarted,
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )
        XCTAssertEqual(started.state.ppt, originalPPT)

        let failed = LiveRuntimeReducer.reduce(
            state: state,
            action: .pptEventTapFailed(reason: "permissionDenied"),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )
        XCTAssertEqual(failed.state.ppt, originalPPT)

        let stopped = LiveRuntimeReducer.reduce(
            state: state,
            action: .pptEventTapStopped(reason: .operatorDisabled),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )
        XCTAssertEqual(stopped.state.ppt, originalPPT)
    }

    func testEnableFailureRecordsFailureButNoSuccessEvent() throws {
        let viewModel = makeViewModel()
        viewModel.testHooks.pageInterceptStartOverride = { false }

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertFalse(viewModel.isPageInterceptEnabled)
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .pageInterceptDisabled })
        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .pptModeChanged })
    }

    func testEnableSuccessRecordsPPTModeChangedOnceAfterEventTapSuccess() throws {
        let viewModel = makeViewModel()
        viewModel.testHooks.pageInterceptStartOverride = { true }

        viewModel.setPPTMode(true, source: .liveMode)

        let successEvents = viewModel.supportEvents.filter { $0.kind == .pptModeChanged }
        XCTAssertEqual(successEvents.count, 1)
        XCTAssertTrue(successEvents[0].detail.contains("isOn=true"))
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "pptEventTapStarted" })
    }

    func testDisableRecordsSource() throws {
        let viewModel = makeViewModel()
        viewModel.pageInterceptSideEffectsEnabled = false

        viewModel.setPPTMode(true, source: .command)
        viewModel.setPPTMode(false, source: .liveMode)

        let event = try XCTUnwrap(viewModel.supportEvents.last(where: { $0.kind == .pptModeChanged }))
        XCTAssertTrue(event.detail.contains("isOn=false"))
        XCTAssertTrue(event.detail.contains("source=liveMode"))
    }

    func testDuplicateSetRecordsNoPPTModeEventEvenThoughRuntimeIntentIsLogged() {
        let viewModel = makeViewModel()
        viewModel.pageInterceptSideEffectsEnabled = false

        viewModel.setPPTMode(false, source: .liveMode)

        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .pptModeChanged })
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSetPPTMode" })
    }

    func testRuntimePPTPortIsUsedAfterMigration() {
        let ppt = PPTModeOwnershipPortSpy()
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, ppt: ppt),
            environment: .productionPPTOwning()
        )
        let viewModel = makeViewModel(runtime: runtime)
        viewModel.pageInterceptSideEffectsEnabled = false

        viewModel.setPPTMode(true, source: .liveMode)
        viewModel.setPPTMode(false, source: .liveMode)

        XCTAssertEqual(ppt.calls, ["start", "stop:operatorDisabled"])
        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "operatorSetPPTMode" })
    }

    func testDispatchPPTIntentStillSetsPendingSource() {
        let viewModel = makePPTRecordingViewModel()

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertEqual(viewModel.currentPendingPPTToggleSource(), .liveMode)
        XCTAssertTrue(viewModel.runtime.state.ppt.isRequested)
    }

    func testDispatchPPTIntentStillClearsPendingSourceWhenRuntimeNoops() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        let viewModel = makePPTRecordingViewModel(initialState: state)

        viewModel.setPPTMode(true, source: .command)

        XCTAssertNil(viewModel.currentPendingPPTToggleSource())
        XCTAssertTrue(viewModel.runtime.state.ppt.isRequested)
    }

    func testPPTWPSKeyForwardingRemainsViewModelOwned() throws {
        let pptEventTapSource = try sourceText("ViewModel+PPTEventTap.swift")
        let effectPortSource = try runtimeSourceText("LiveRuntimeEffectPortKind.swift")

        XCTAssertTrue(pptEventTapSource.contains("nonisolated private func sendPageKeyToWPS"))
        XCTAssertTrue(pptEventTapSource.contains("currentWPSProcessIdentifierForPageForwarding()"))
        XCTAssertTrue(pptEventTapSource.contains("postToPid(targetPID)"))
        XCTAssertFalse(effectPortSource.contains("wps"))
        XCTAssertFalse(effectPortSource.contains("pageForwarding"))
    }

    func testAllPPTUIAndCommandPathsUseHelperAndAvoidDirectToggle() throws {
        let pptModeSource = try sourceText("ViewModel+PPTMode.swift")
        let toolbarSource = try sourceText("Views/MainToolbar.swift")
        let appSource = try sourceText("App.swift")

        XCTAssertTrue(pptModeSource.contains("func setPPTMode"))
        XCTAssertTrue(toolbarSource.contains("viewModel.togglePPTMode(source: pptModeToggleSource)"))
        XCTAssertTrue(appSource.contains("viewModel.togglePPTMode(source: .command)"))
        XCTAssertFalse(pptModeSource.contains("isPageInterceptEnabled.toggle()"))
        XCTAssertFalse(toolbarSource.contains("isPageInterceptEnabled.toggle()"))
        XCTAssertFalse(appSource.contains("isPageInterceptEnabled.toggle()"))
    }

    private func makePPTRecordingViewModel(initialState: LiveRuntimeState = LiveRuntimeState()) -> SwitcherViewModel {
        makeViewModel(runtime: LiveRuntimeStore(
            initialState: initialState,
            effectRunner: .recording(),
            environment: .productionPPTOwning()
        ))
    }

    private func makeViewModel(runtime: LiveRuntimeStore? = nil) -> SwitcherViewModel {
        let suiteName = "PPTModeOwnershipTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults,
            runtime: runtime
        )
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func runtimeSourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: runtimeSourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }

    private func runtimeSourceURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate runtime \(relativePath) from test source path.")
    }
}

private final class PPTModeOwnershipPortSpy: PPTEventTapPort {
    private(set) var calls: [String] = []

    func start() {
        calls.append("start")
    }

    func stop(reason: PPTStopReason) {
        calls.append("stop:\(reason.rawValue)")
    }
}
