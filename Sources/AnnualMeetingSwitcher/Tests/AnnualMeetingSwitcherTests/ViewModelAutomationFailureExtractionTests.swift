import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelAutomationFailureExtractionTests: XCTestCase {
    func testAutomationFailureMethodsAreNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()
        let forbiddenSnippets = [
            "func handleAppleScriptFailure(",
            "func dismissAutomationRuntimeNotice(",
            "func expireAutomationRuntimeNotice(",
            "func showAutomationRuntimeNotice(",
            "func cancelAutomationNoticeExpiryTask(",
            "func expireAutomationNoticeFromScheduledTask(",
            "var automationNoticeExpiryTaskIsActiveForTesting",
            "var automationNoticeExpiryTaskNoticeIDForTesting",
            "func expireAutomationNoticeFromScheduledTaskForTesting(",
            "func presentAutomationAlert(",
            "func performAutomationAlert(",
            "func canPresentAutomationAlert(",
            "func sanitizedAutomationFailureMessage("
        ]

        for snippet in forbiddenSnippets {
            XCTAssertFalse(source.contains(snippet), snippet)
        }
    }

    func testAutomationFailureMethodsLiveInAutomationFailureExtension() throws {
        let source = try XCTUnwrap(automationFailureExtensionSource())

        XCTAssertTrue(source.contains("extension SwitcherViewModel"))
        for snippet in [
            "func handleAppleScriptFailure(",
            "func dismissAutomationRuntimeNotice(",
            "func expireAutomationRuntimeNotice(",
            "func showAutomationRuntimeNotice(",
            "func cancelAutomationNoticeExpiryTask(",
            "func expireAutomationNoticeFromScheduledTask(",
            "var automationNoticeExpiryTaskIsActiveForTesting",
            "var automationNoticeExpiryTaskNoticeIDForTesting",
            "func expireAutomationNoticeFromScheduledTaskForTesting(",
            "func presentAutomationAlert(",
            "func performAutomationAlert(",
            "func canPresentAutomationAlert(",
            "func sanitizedAutomationFailureMessage("
        ] {
            XCTAssertTrue(source.contains(snippet), snippet)
        }
    }

    func testAppleScriptFailureStillRecordsSupportThroughRuntime() {
        let viewModel = makeViewModel()

        viewModel.handleAppleScriptFailure(failure(), action: "keynote.next-slide")

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .appleScriptFailed })
        XCTAssertTrue(viewModel.runtime.state.support.events.contains { $0.kind == .appleScriptFailed })
    }

    func testAppleScriptFailureStillCreatesAutomationNotice() {
        let viewModel = makeViewModel()

        viewModel.handleAppleScriptFailure(failure(), action: "keynote.next-slide")

        XCTAssertEqual(viewModel.automationRuntimeNotice?.action, "keynote.next-slide")
    }

    func testAutomationFailureStillUsesSanitizedMessage() throws {
        let body = try functionBody("handleAppleScriptFailure")

        XCTAssertTrue(body.contains("sanitizedAutomationFailureMessage(error)"))
        XCTAssertTrue(body.contains("AutomationFailureSanitizer.sanitizedSupportMessage(from: error)"))
    }

    func testAutomationNoticeDismissStillClearsFacadeNotice() {
        let viewModel = makeViewModel()
        viewModel.dispatchRuntimeFacadeAction(.automationNoticeRequested(action: "keynote.next-slide"))

        viewModel.dismissAutomationRuntimeNotice()

        XCTAssertNil(viewModel.automationRuntimeNotice)
        XCTAssertNil(viewModel.runtime.state.automation.notice)
    }

    func testAutomationNoticeExpiryStillUsesRuntimeAction() throws {
        let body = try functionBody("expireAutomationNoticeFromScheduledTask")

        XCTAssertTrue(body.contains("dispatchRuntimeFacadeAction(.automationNoticeExpired(id))"))
    }

    func testAutomationAlertSuppressionStillWorks() throws {
        let body = try functionBody("performAutomationAlert")

        XCTAssertTrue(body.contains("guard canPresentAutomationAlert(action: action) else { return }"))
        XCTAssertTrue(body.contains("automationAlertSuppressionUntilByAction[action] = Date()"))
    }

    private func viewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }

    private func automationFailureExtensionSource() throws -> String? {
        try optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+AutomationFailure.swift")
    }

    private func functionBody(_ name: String) throws -> String {
        let source = try XCTUnwrap(automationFailureExtensionSource())
        return try XCTUnwrap(source.extractedRuntimeFunctionBody(named: name))
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "ViewModelAutomationFailureExtractionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
    }

    private func failure() -> Error {
        AppleScriptError.executionFailed(action: "keynote.next-slide", message: "/Users/private/demo.key failed")
    }
}
