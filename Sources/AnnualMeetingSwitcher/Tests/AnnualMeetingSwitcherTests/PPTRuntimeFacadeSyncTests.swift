import XCTest
@testable import LiveSwitcher

@MainActor
final class PPTRuntimeFacadeSyncTests: XCTestCase {
    func testPPTFacadeSyncProjectsRequestedStateTrue() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        state.ppt.isEventTapActive = false
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .pptOwned)
        viewModel.isPageInterceptEnabled = false

        viewModel.syncPPTFacadeFromRuntime()

        XCTAssertTrue(viewModel.isPageInterceptEnabled)
    }

    func testPPTFacadeSyncProjectsActiveStateTrue() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = false
        state.ppt.isEventTapActive = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .pptOwned)
        viewModel.isPageInterceptEnabled = false

        viewModel.syncPPTFacadeFromRuntime()

        XCTAssertTrue(viewModel.isPageInterceptEnabled)
    }

    func testPPTFacadeSyncProjectsRequestedOrActiveTrue() {
        var requested = LiveRuntimeState()
        requested.ppt.isRequested = true
        requested.ppt.isEventTapActive = false
        let requestedViewModel = makeViewModel(runtimeState: requested, bridgeMode: .pptOwned)

        requestedViewModel.syncPPTFacadeFromRuntime()

        var active = LiveRuntimeState()
        active.ppt.isRequested = false
        active.ppt.isEventTapActive = true
        let activeViewModel = makeViewModel(runtimeState: active, bridgeMode: .pptOwned)

        activeViewModel.syncPPTFacadeFromRuntime()

        XCTAssertTrue(requestedViewModel.isPageInterceptEnabled)
        XCTAssertTrue(activeViewModel.isPageInterceptEnabled)
    }

    func testPPTFacadeSyncProjectsFalseWhenNotRequestedAndNotActive() {
        let viewModel = makeViewModel(runtimeState: LiveRuntimeState(), bridgeMode: .pptOwned)
        viewModel.isPageInterceptEnabled = true

        viewModel.syncPPTFacadeFromRuntime()

        XCTAssertFalse(viewModel.isPageInterceptEnabled)
    }

    func testPPTFacadeSyncNoopsBeforePPTOwnership() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        state.ppt.isEventTapActive = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .projectionOwned)
        viewModel.isPageInterceptEnabled = false

        viewModel.syncPPTFacadeFromRuntime()

        XCTAssertFalse(viewModel.isPageInterceptEnabled)
    }

    func testPPTFacadeSyncDoesNotUseEventTapActiveOnly() throws {
        let source = try runtimeFacadeSyncSource()
        let body = try functionBody(named: "syncPPTFacadeFromRuntime", in: source)

        XCTAssertFalse(body.contains("isPageInterceptEnabled = runtime.state.ppt.isEventTapActive"))
    }

    func testPPTFacadeSyncUsesRequestedOrActiveExpression() throws {
        let source = try runtimeFacadeSyncSource()
        let body = try functionBody(named: "syncPPTFacadeFromRuntime", in: source)

        XCTAssertTrue(body.contains("runtime.state.ppt.isRequested || runtime.state.ppt.isEventTapActive"))
    }

    func testSetPPTModeTrueKeepsFacadeEnabledWhileEventTapStartPending() {
        let viewModel = makeViewModel(runtimeState: LiveRuntimeState(), bridgeMode: .pptOwned)
        viewModel.isPageInterceptEnabled = false

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertTrue(viewModel.runtime.state.ppt.isRequested)
        XCTAssertFalse(viewModel.runtime.state.ppt.isEventTapActive)
        XCTAssertTrue(viewModel.isPageInterceptEnabled)
    }

    func testTogglePPTModeOnKeepsFacadeEnabledWhileEventTapStartPending() {
        let viewModel = makeViewModel(runtimeState: LiveRuntimeState(), bridgeMode: .pptOwned)
        viewModel.isPageInterceptEnabled = false

        viewModel.togglePPTMode(source: .liveMode)

        XCTAssertTrue(viewModel.runtime.state.ppt.isRequested)
        XCTAssertFalse(viewModel.runtime.state.ppt.isEventTapActive)
        XCTAssertTrue(viewModel.isPageInterceptEnabled)
    }

    func testOperatorSetPPTModeTrueProjectsRequestedBeforeStartedCallback() {
        let viewModel = makeViewModel(runtimeState: LiveRuntimeState(), bridgeMode: .pptOwned)

        viewModel.dispatchRuntimeFacadeAction(.operatorSetPPTMode(true, source: .liveMode))

        XCTAssertTrue(viewModel.runtime.state.ppt.isRequested)
        XCTAssertFalse(viewModel.runtime.state.ppt.isEventTapActive)
        XCTAssertTrue(viewModel.isPageInterceptEnabled)
    }

    func testOperatorToggledPPTModeOnProjectsRequestedBeforeStartedCallback() {
        let viewModel = makeViewModel(runtimeState: LiveRuntimeState(), bridgeMode: .pptOwned)

        viewModel.dispatchRuntimeFacadeAction(.operatorToggledPPTMode(source: .liveMode))

        XCTAssertTrue(viewModel.runtime.state.ppt.isRequested)
        XCTAssertFalse(viewModel.runtime.state.ppt.isEventTapActive)
        XCTAssertTrue(viewModel.isPageInterceptEnabled)
    }

    func testPPTIntentDoesNotFlipFacadeOffBeforeEventTapStarted() {
        let viewModel = makeViewModel(runtimeState: LiveRuntimeState(), bridgeMode: .pptOwned)

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertTrue(viewModel.isPageInterceptEnabled)
        XCTAssertTrue(viewModel.runtime.recordedEffects.contains(.startPPTEventTap))
    }

    func testPPTOwnedFacadeSyncPreservesRuntimeRequested() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .pptOwned)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        XCTAssertTrue(viewModel.runtime.state.ppt.isRequested)
    }

    func testPPTOwnedFacadeSyncPreservesRuntimeActive() {
        var state = LiveRuntimeState()
        state.ppt.isEventTapActive = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .pptOwned)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        XCTAssertTrue(viewModel.runtime.state.ppt.isEventTapActive)
    }

    func testPPTOwnedFacadeSyncPreservesRuntimeFailureReason() {
        var state = LiveRuntimeState()
        state.ppt.lastFailureReason = "accessibilityPermission"
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .pptOwned)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        XCTAssertEqual(viewModel.runtime.state.ppt.lastFailureReason, "accessibilityPermission")
    }

    func testNonPPTOwnedFacadeSyncMirrorsViewModelState() {
        let viewModel = makeViewModel(runtimeState: LiveRuntimeState(), bridgeMode: .projectionOwned)
        viewModel.isPageInterceptEnabled = true

        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        XCTAssertTrue(viewModel.runtime.state.ppt.isRequested)
    }

    func testPPTOwnedSnapshotPreservesRuntimeRequested() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        state.ppt.isEventTapActive = false
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .pptOwned)
        viewModel.isPageInterceptEnabled = false

        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        XCTAssertTrue(viewModel.runtime.state.ppt.isRequested)
        XCTAssertFalse(viewModel.runtime.state.ppt.isEventTapActive)
    }

    func testPPTOwnedSnapshotPreservesRuntimeActive() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        state.ppt.isEventTapActive = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .pptOwned)
        viewModel.isPageInterceptEnabled = false

        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        XCTAssertTrue(viewModel.runtime.state.ppt.isRequested)
        XCTAssertTrue(viewModel.runtime.state.ppt.isEventTapActive)
    }

    func testPPTOwnedSnapshotPreservesRuntimeFailureReason() {
        var state = LiveRuntimeState()
        state.ppt.lastFailureReason = "accessibilityPermission"
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .pptOwned)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        XCTAssertEqual(viewModel.runtime.state.ppt.lastFailureReason, "accessibilityPermission")
    }

    func testNonPPTOwnedSnapshotMirrorsViewModelRequestedState() {
        let viewModel = makeViewModel(runtimeState: LiveRuntimeState(), bridgeMode: .projectionOwned)
        viewModel.isPageInterceptEnabled = true

        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)

        XCTAssertTrue(viewModel.runtime.state.ppt.isRequested)
    }

    func testPPTEventTapStartedSyncsIsPageInterceptEnabledTrue() {
        let viewModel = makeViewModel(runtimeState: LiveRuntimeState(), bridgeMode: .pptOwned)

        viewModel.dispatchRuntimeFacadeAction(.pptEventTapStarted)

        XCTAssertTrue(viewModel.isPageInterceptEnabled)
    }

    func testPPTEventTapFailedSyncsIsPageInterceptEnabledFalse() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .pptOwned)

        viewModel.dispatchRuntimeFacadeAction(.pptEventTapFailed(reason: "accessibilityPermission"))

        XCTAssertFalse(viewModel.isPageInterceptEnabled)
    }

    func testPPTEventTapFailedPreservesFailureReasonInRuntime() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .pptOwned)

        viewModel.dispatchRuntimeFacadeAction(.pptEventTapFailed(reason: "accessibilityPermission"))

        XCTAssertEqual(viewModel.runtime.state.ppt.lastFailureReason, "accessibilityPermission")
    }

    func testPPTEventTapStoppedSyncsIsPageInterceptEnabledFalse() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        state.ppt.isEventTapActive = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .pptOwned)

        viewModel.dispatchRuntimeFacadeAction(.pptEventTapStopped(reason: .operatorDisabled))

        XCTAssertFalse(viewModel.isPageInterceptEnabled)
    }

    func testPPTEventTapStoppedDoesNotClearLastFailureReasonUnexpectedly() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        state.ppt.isEventTapActive = true
        state.ppt.lastFailureReason = "accessibilityPermission"
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .pptOwned)

        viewModel.dispatchRuntimeFacadeAction(.pptEventTapStopped(reason: .operatorDisabled))

        XCTAssertEqual(viewModel.runtime.state.ppt.lastFailureReason, "accessibilityPermission")
        XCTAssertFalse(viewModel.isPageInterceptEnabled)
    }

    private func makeViewModel(
        runtimeState: LiveRuntimeState,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            initialState: runtimeState,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
    }

    private func runtimeFacadeSyncSource() throws -> String {
        try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeFacadeSync.swift"
        )
    }

    private func functionBody(named name: String, in source: String) throws -> String {
        guard let range = source.range(of: "func \(name)") else {
            XCTFail("Missing function \(name)")
            return ""
        }
        var depth = 0
        var body = ""
        var hasEnteredBody = false
        for character in source[range.lowerBound...] {
            body.append(character)
            if character == "{" {
                depth += 1
                hasEnteredBody = true
            } else if character == "}" {
                depth -= 1
                if hasEnteredBody && depth == 0 {
                    break
                }
            }
        }
        return body
    }
}
