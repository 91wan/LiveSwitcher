import XCTest
@testable import LiveSwitcher

@MainActor
final class LiveRuntimePPTAutomationBridgeTests: XCTestCase {
    func testPPTModeChangeDispatchesRuntimeOperatorAction() throws {
        let viewModel = makeViewModel()
        viewModel.pageInterceptSideEffectsEnabled = false

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorToggledPPTMode" })
        XCTAssertEqual(viewModel.runtime.actionLog.last?.actionName, "supportEventRecorded")
        XCTAssertTrue(viewModel.runtime.state.ppt.isRequested)
    }

    func testPPTModeDuplicateSetDoesNotDispatchRuntimeAction() throws {
        let viewModel = makeViewModel()
        viewModel.pageInterceptSideEffectsEnabled = false

        viewModel.setPPTMode(false, source: .liveMode)

        XCTAssertTrue(viewModel.runtime.actionLog.isEmpty)
    }

    func testAppleScriptFailureDispatchesRuntimeAutomationFailure() throws {
        let viewModel = makeViewModel()
        let error = AppleScriptError.executionFailed(
            action: "keynote.next-slide",
            message: "/Users/operator/private-show.key failed"
        )

        viewModel.handleAppleScriptFailure(error, action: "keynote.next-slide")

        XCTAssertEqual(viewModel.runtime.actionLog.last?.actionName, "automationFailed")
        XCTAssertEqual(viewModel.runtime.state.automation.notice?.action, "keynote.next-slide")
        XCTAssertEqual(viewModel.automationRuntimeNotice?.action, "keynote.next-slide")
        XCTAssertTrue(viewModel.runtime.state.support.events.contains { $0.kind == .appleScriptFailed })
        XCTAssertFalse(viewModel.runtime.state.support.events.contains {
            $0.detail.localizedStandardContains("/Users/") || $0.detail.localizedStandardContains("private-show.key")
        })
    }

    func testUnavailableProgramSourceRequestsRuntimeAutomationNotice() throws {
        let viewModel = makeViewModel()
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        let item = ProgramItem(title: "Missing Video", subtitle: "VIDEO", sourceURL: missingURL)
        viewModel.programItems = [item]

        viewModel.switchToProgram(item)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "automationNoticeRequested" })
        XCTAssertEqual(viewModel.runtime.state.automation.notice?.action, "program.source.missing")
        XCTAssertEqual(viewModel.automationRuntimeNotice?.action, "program.source.missing")
        XCTAssertTrue(viewModel.runtime.recordedEffects.contains {
            if case .showAutomationNotice(let notice) = $0 {
                return notice.action == "program.source.missing"
            }
            return false
        })
        XCTAssertTrue(viewModel.runtime.state.support.events.contains { $0.kind == .programItemFileMissing })
    }

    func testAutomationNoticeDismissalAndExpiryDispatchRuntimeActions() throws {
        let viewModel = makeViewModel()
        let notice = AutomationRuntimeNoticePolicy.make(
            action: "wps.open.command",
            createdAt: Date(timeIntervalSince1970: 1_000)
        )

        viewModel.automationRuntimeNotice = notice
        viewModel.dismissAutomationRuntimeNotice()

        XCTAssertEqual(viewModel.runtime.actionLog.last?.actionName, "automationNoticeDismissed")
        XCTAssertNil(viewModel.runtime.state.automation.notice)

        let expiringNotice = AutomationRuntimeNoticePolicy.make(
            action: "keynote.next-slide",
            createdAt: Date(timeIntervalSince1970: 2_000)
        )
        viewModel.automationRuntimeNotice = expiringNotice

        viewModel.expireAutomationRuntimeNotice(
            id: expiringNotice.id,
            now: expiringNotice.expiresAt!.addingTimeInterval(1)
        )

        XCTAssertEqual(viewModel.runtime.actionLog.last?.actionName, "automationNoticeExpired")
        XCTAssertNil(viewModel.runtime.state.automation.notice)
    }

    func testAutomationFailureRuntimeNoticeThrottlesSameActionButKeepsSupportTimeline() throws {
        let viewModel = makeViewModel()

        viewModel.handleAppleScriptFailure(
            AppleScriptError.executionFailed(action: "keynote.next-slide", message: "first"),
            action: "keynote.next-slide"
        )
        let firstNotice = viewModel.runtime.state.automation.notice

        viewModel.handleAppleScriptFailure(
            AppleScriptError.executionFailed(action: "keynote.next-slide", message: "first"),
            action: "keynote.next-slide"
        )

        XCTAssertEqual(viewModel.runtime.state.automation.notice, firstNotice)
        let runtimeFailures = viewModel.runtime.state.support.events.filter { $0.kind == .appleScriptFailed }
        XCTAssertEqual(runtimeFailures.count, 1)
        XCTAssertTrue(runtimeFailures[0].detail.contains("count=2"))
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "LiveRuntimePPTAutomationBridgeTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults
        )
    }
}
