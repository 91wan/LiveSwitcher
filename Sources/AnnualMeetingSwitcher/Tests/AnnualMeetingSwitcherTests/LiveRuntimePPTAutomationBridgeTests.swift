import XCTest
@testable import LiveSwitcher

@MainActor
final class LiveRuntimePPTAutomationBridgeTests: XCTestCase {
    func testPPTModeChangeDispatchesRuntimeOperatorAction() throws {
        let viewModel = makeViewModel()
        viewModel.pageInterceptSideEffectsEnabled = false

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSetPPTMode" })
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "supportEventRecorded" })
        XCTAssertTrue(viewModel.runtime.state.ppt.isRequested)
    }

    func testPPTModeDuplicateSetDispatchesRuntimeNoopWithoutSupportEvent() throws {
        let viewModel = makeViewModel()
        viewModel.pageInterceptSideEffectsEnabled = false

        viewModel.setPPTMode(false, source: .liveMode)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSetPPTMode" })
        XCTAssertTrue(viewModel.supportEvents.isEmpty)
    }

    func testPPTModeSideEffectsRouteThroughRuntimePortAfterMigration() throws {
        let ppt = PPTEventTapPortSpy()
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, ppt: ppt),
            environment: .productionPPTOwning()
        )
        let viewModel = makeViewModel(runtime: runtime)
        viewModel.pageInterceptSideEffectsEnabled = false

        viewModel.setPPTMode(true, source: .liveMode)
        viewModel.setPPTMode(false, source: .liveMode)

        XCTAssertEqual(ppt.calls, ["start", "stop:operatorDisabled"])
    }

    func testPPTModeStateDoesNotOwnEventTapSideEffectsInDidSet() throws {
        let source = try sourceText("ViewModel.swift")

        XCTAssertFalse(source.contains("didSet { applyPageInterceptState() }"))
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

        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "automationNoticeRequested" })
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

        viewModel.dispatchRuntimeFacadeAction(.automationNoticeRequested(action: "keynote.next-slide"))
        let expiringNotice = try XCTUnwrap(viewModel.automationRuntimeNotice)
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)

        viewModel.expireAutomationRuntimeNotice(
            id: expiringNotice.id,
            now: expiringNotice.expiresAt!.addingTimeInterval(1)
        )

        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "automationNoticeExpired" })
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

    private func makeViewModel(runtime: LiveRuntimeStore? = nil) -> SwitcherViewModel {
        let suiteName = "LiveRuntimePPTAutomationBridgeTests.\(UUID().uuidString)"
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

private final class PPTEventTapPortSpy: PPTEventTapPort {
    private(set) var calls: [String] = []

    func start() {
        calls.append("start")
    }

    func stop(reason: PPTStopReason) {
        calls.append("stop:\(reason.rawValue)")
    }
}
