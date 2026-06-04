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

    func testAudioOwnedPPTCallbacksUpdateMirrorState() {
        let started = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .pptEventTapStarted,
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )
        XCTAssertTrue(started.state.ppt.isRequested)
        XCTAssertTrue(started.state.ppt.isEventTapActive)

        let failed = LiveRuntimeReducer.reduce(
            state: started.state,
            action: .pptEventTapFailed(reason: "permissionDenied"),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )
        XCTAssertFalse(failed.state.ppt.isRequested)
        XCTAssertFalse(failed.state.ppt.isEventTapActive)
        XCTAssertEqual(failed.state.ppt.lastFailureReason, "permissionDenied")

        let stopped = LiveRuntimeReducer.reduce(
            state: started.state,
            action: .pptEventTapStopped(reason: .operatorDisabled),
            environment: LiveRuntimeEnvironment(bridgeMode: .audioOwned)
        )
        XCTAssertFalse(stopped.state.ppt.isRequested)
        XCTAssertFalse(stopped.state.ppt.isEventTapActive)
    }

    func testEnableFailureRecordsFailureButNoSuccessEvent() throws {
        let viewModel = makeViewModel()
        viewModel.pageInterceptStartOverride = { false }

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertFalse(viewModel.isPageInterceptEnabled)
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .pageInterceptDisabled })
        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .pptModeChanged })
    }

    func testEnableSuccessRecordsPPTModeChangedOnceAfterEventTapSuccess() throws {
        let viewModel = makeViewModel()
        viewModel.pageInterceptStartOverride = { true }

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

    func testDuplicateSetRecordsNoPPTModeEvent() {
        let viewModel = makeViewModel()
        viewModel.pageInterceptSideEffectsEnabled = false

        viewModel.setPPTMode(false, source: .liveMode)

        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .pptModeChanged })
        XCTAssertTrue(viewModel.runtime.actionLog.isEmpty)
    }

    func testRuntimePPTPortIsRecordingOnlyDuringCurrentMigration() {
        let ppt = PPTModeOwnershipPortSpy()
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, ppt: ppt),
            environment: .productionAudioOwned()
        )
        let viewModel = makeViewModel(runtime: runtime)
        viewModel.pageInterceptSideEffectsEnabled = false

        viewModel.setPPTMode(true, source: .liveMode)
        viewModel.setPPTMode(false, source: .liveMode)

        XCTAssertTrue(ppt.calls.isEmpty)
        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "operatorToggledPPTMode" })
    }

    func testAllPPTUIAndCommandPathsUseHelperAndAvoidDirectToggle() throws {
        let viewModelSource = try sourceText("ViewModel.swift")
        let toolbarSource = try sourceText("Views/MainToolbar.swift")
        let appSource = try sourceText("App.swift")

        XCTAssertTrue(viewModelSource.contains("func setPPTMode"))
        XCTAssertTrue(toolbarSource.contains("viewModel.togglePPTMode(source: pptModeToggleSource)"))
        XCTAssertTrue(appSource.contains("viewModel.togglePPTMode(source: .command)"))
        XCTAssertFalse(viewModelSource.contains("isPageInterceptEnabled.toggle()"))
        XCTAssertFalse(toolbarSource.contains("isPageInterceptEnabled.toggle()"))
        XCTAssertFalse(appSource.contains("isPageInterceptEnabled.toggle()"))
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
