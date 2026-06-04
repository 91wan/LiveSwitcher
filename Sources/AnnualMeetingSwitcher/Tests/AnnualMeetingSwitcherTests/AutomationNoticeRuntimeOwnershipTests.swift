import XCTest
@testable import LiveSwitcher

@MainActor
final class AutomationNoticeRuntimeOwnershipTests: XCTestCase {
    func testShowAutomationRuntimeNoticeUsesRuntimeNoticeAction() throws {
        let source = try sourceText("ViewModel.swift")
        let body = try XCTUnwrap(source.functionBody(named: "showAutomationRuntimeNotice"))

        XCTAssertTrue(body.contains("dispatchRuntimeFacadeAction(.automationNoticeRequested(action: action))"))
        XCTAssertTrue(body.contains("syncAutomationNoticeFacadeFromRuntime()"))
    }

    func testAppleScriptFailureRecordsSupportThroughViewModel() {
        let viewModel = makeViewModel()

        viewModel.handleAppleScriptFailure(
            AppleScriptError.executionFailed(action: "keynote.next-slide", message: "failed"),
            action: "keynote.next-slide"
        )

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .appleScriptFailed })
    }

    func testAppleScriptFailureDispatchesRuntimeAutomationFailed() {
        let viewModel = makeViewModel()

        viewModel.handleAppleScriptFailure(
            AppleScriptError.executionFailed(action: "keynote.next-slide", message: "failed"),
            action: "keynote.next-slide"
        )

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "automationFailed" })
    }

    func testRepeatedAutomationFailureCoalescesSupportButSuppressesRepeatedNotice() throws {
        let viewModel = makeViewModel()

        viewModel.handleAppleScriptFailure(
            AppleScriptError.executionFailed(action: "keynote.next-slide", message: "failed"),
            action: "keynote.next-slide"
        )
        let firstNotice = try XCTUnwrap(viewModel.automationRuntimeNotice)
        viewModel.handleAppleScriptFailure(
            AppleScriptError.executionFailed(action: "keynote.next-slide", message: "failed"),
            action: "keynote.next-slide"
        )

        XCTAssertEqual(viewModel.automationRuntimeNotice, firstNotice)
        let failures = viewModel.supportEvents.filter { $0.kind == .appleScriptFailed }
        XCTAssertEqual(failures.count, 1)
        XCTAssertTrue(failures[0].detail.contains("count=2"))
    }

    func testAutomationFailureNoticeDoesNotLeakFilePath() throws {
        let viewModel = makeViewModel()

        viewModel.handleAppleScriptFailure(
            AppleScriptError.executionFailed(
                action: "keynote.next-slide",
                message: "/Users/operator/private-show.key failed"
            ),
            action: "keynote.next-slide"
        )

        let notice = try XCTUnwrap(viewModel.automationRuntimeNotice)
        XCTAssertFalse(notice.title.localizedStandardContains("/Users/"))
        XCTAssertFalse(notice.message.localizedStandardContains("/Users/"))
        XCTAssertFalse(notice.message.localizedStandardContains("private-show.key"))
    }

    func testAutomationFailedNoticeDoesNotUseSanitizedMessageAsVisibleCopy() throws {
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .automationFailed(
                action: "keynote.next-slide",
                sanitizedMessage: "raw script source /Users/operator/private-show.key customer line"
            ),
            environment: .productionAutomationNoticeOwning(now: Date(timeIntervalSince1970: 100))
        )

        let notice = try XCTUnwrap(mutation.state.automation.notice)
        XCTAssertFalse(notice.title.localizedStandardContains("raw script source"))
        XCTAssertFalse(notice.message.localizedStandardContains("raw script source"))
        XCTAssertFalse(notice.message.localizedStandardContains("/Users/operator"))
        XCTAssertFalse(notice.message.localizedStandardContains("customer line"))
    }

    func testAutomationFailedNoticeUsesActionPolicyCopy() throws {
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .automationFailed(action: "keynote.next-slide", sanitizedMessage: "failed"),
            environment: .productionAutomationNoticeOwning(now: Date(timeIntervalSince1970: 100))
        )

        let notice = try XCTUnwrap(mutation.state.automation.notice)
        XCTAssertEqual(notice.title, "翻页未发送")
        XCTAssertEqual(notice.primaryAction, .openSafetyCockpit)
    }

    func testPermissionNoticeUsesOpenSystemSettingsAction() {
        let notice = AutomationRuntimeNoticePolicy.make(action: "accessibilityPermission.denied")

        XCTAssertEqual(notice.primaryAction, .openSystemSettingsAccessibility)
    }

    func testWPSPageNoticeUsesSafetyCockpitAction() {
        let notice = AutomationRuntimeNoticePolicy.make(action: "wps.page.next")

        XCTAssertEqual(notice.primaryAction, .openSafetyCockpit)
    }

    func testProgramSourceMissingNoticeUsesSafetyCockpitAction() {
        let notice = AutomationRuntimeNoticePolicy.make(action: "program.source.missing")

        XCTAssertEqual(notice.primaryAction, .openSafetyCockpit)
    }

    func testProgramSourceMissingUsesRuntimeNotice() {
        let viewModel = makeViewModel()
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        let item = ProgramItem(title: "Missing Video", subtitle: "VIDEO", sourceURL: missingURL)
        viewModel.programItems = [item]

        viewModel.switchToProgram(item)

        XCTAssertTrue(viewModel.runtime.recordedEffects.contains { effect in
            if case .showAutomationNotice(let notice) = effect {
                return notice.action == "program.source.missing"
            }
            return false
        })
        XCTAssertEqual(viewModel.automationRuntimeNotice?.action, "program.source.missing")
    }

    func testAutomationNoticeDismissedClearsViewModelFacade() {
        let viewModel = makeViewModel()
        viewModel.dispatchRuntimeFacadeAction(.automationNoticeRequested(action: "keynote.next-slide"))

        viewModel.dismissAutomationRuntimeNotice()

        XCTAssertNil(viewModel.automationRuntimeNotice)
        XCTAssertNil(viewModel.runtime.state.automation.notice)
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "AutomationNoticeRuntimeOwnershipTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults
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

private extension String {
    func functionBody(named functionName: String) -> String? {
        guard let nameRange = range(of: "func \(functionName)") else { return nil }
        guard let openingBrace = self[nameRange.lowerBound...].firstIndex(of: "{") else { return nil }
        var depth = 0
        var index = openingBrace
        while index < endIndex {
            if self[index] == "{" {
                depth += 1
            } else if self[index] == "}" {
                depth -= 1
                if depth == 0 {
                    return String(self[openingBrace...index])
                }
            }
            index = self.index(after: index)
        }
        return nil
    }
}
