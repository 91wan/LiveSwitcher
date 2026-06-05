import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelPPTEventTapBehaviorTests: XCTestCase {
    func testStartPPTEventTapFromRuntimeStillDispatchesStartedCallbackOnSuccess() {
        let viewModel = makeViewModel()
        viewModel.pageInterceptSideEffectsEnabled = false

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertTrue(viewModel.runtime.state.ppt.isEventTapActive)
        XCTAssertTrue(viewModel.isPageInterceptEnabled)
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .pageInterceptEnabled })
    }

    func testStartPPTEventTapFailureStillRollsBackRuntimeState() {
        let viewModel = makeViewModel()
        viewModel.pageInterceptStartOverride = { false }

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertFalse(viewModel.runtime.state.ppt.isRequested)
        XCTAssertFalse(viewModel.runtime.state.ppt.isEventTapActive)
        XCTAssertEqual(viewModel.runtime.state.ppt.lastFailureReason, "overrideFailed")
    }

    func testStopPPTEventTapFromRuntimeStillDispatchesStoppedCallback() {
        let viewModel = makeViewModel()
        viewModel.pageInterceptSideEffectsEnabled = false
        viewModel.setPPTMode(true, source: .command)

        viewModel.setPPTMode(false, source: .liveMode)

        XCTAssertFalse(viewModel.runtime.state.ppt.isRequested)
        XCTAssertFalse(viewModel.runtime.state.ppt.isEventTapActive)
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .pageInterceptDisabled })
    }

    func testPageInterceptPermissionFailureStillShowsAutomationAlert() throws {
        let source = try pptEventTapSource()

        XCTAssertTrue(source.contains("presentAutomationAlert("))
        XCTAssertTrue(source.contains("pageIntercept.accessibilityPermission"))
    }

    func testPageInterceptReenableStillRecordsSupportEvent() {
        let viewModel = makeViewModel()

        viewModel.reenablePageIntercept(reason: .timeout)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .pageInterceptAutoReenabled })
    }

    func testHandlePageInterceptKeyStillRoutesHTMLBridgeFirst() throws {
        let source = try pptEventTapSource()
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "handlePageInterceptKey"))

        XCTAssertTrue(body.contains("HTMLWebViewBridge.shared.hasActiveWebView"))
        XCTAssertTrue(body.contains("HTMLWebViewBridge.shared.dispatchArrowKey(isNext: true)"))
        XCTAssertTrue(body.contains("sendPageKeyToWPS(isPageDown: true)"))
    }

    func testHandlePageInterceptKeyStillFallsBackToWPSForwarding() {
        let viewModel = makeViewModel()

        XCTAssertTrue(viewModel.handlePageInterceptKey(keyCode: 121))
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertTrue(
            viewModel.supportEvents.contains { event in
                event.kind == .pageInterceptWPSNotRunning || event.kind == .pageInterceptForwardedToWPS
            }
        )
    }

    func testWPSNotRunningStillRecordsSupportAndShowsAutomationNotice() throws {
        let hasRunningWPS = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == AppConfiguration.wpsBundleIdentifier
        }
        if hasRunningWPS {
            throw XCTSkip("WPS is running on this host; missing-WPS intercept path is not deterministic.")
        }
        let viewModel = makeViewModel()

        XCTAssertTrue(viewModel.handlePageInterceptKey(keyCode: 121))
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .pageInterceptWPSNotRunning })
        XCTAssertEqual(viewModel.automationRuntimeNotice?.title, "演示软件未运行")
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "ViewModelPPTEventTapBehaviorTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults
        )
    }

    private func pptEventTapSource() throws -> String {
        if let source = try optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PPTEventTap.swift") {
            return source
        }
        return try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }
}
