import XCTest
@testable import LiveSwitcher

@MainActor
final class AutomationCommandRuntimePrivacyTests: XCTestCase {
    func testAutomationFailedActionReceivesSanitizedMessage() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
        let body = try XCTUnwrap(source.functionBody(named: "handleAppleScriptFailure"))

        XCTAssertTrue(body.contains("let sanitizedMessage = sanitizedAutomationFailureMessage(error)"))
        XCTAssertTrue(body.contains("let supportMessage = AutomationFailureSanitizer.sanitizedSupportMessage(from: error)"))
        XCTAssertTrue(body.contains("recordSupportEvent(kind: .appleScriptFailed, detail: \"action=\\(action),error=\\(supportMessage)"))
        XCTAssertTrue(body.contains("dispatchRuntimeFacadeAction(.automationFailed(action: action, sanitizedMessage: sanitizedMessage))"))
        XCTAssertFalse(body.contains("appleScriptFailureMessage(error)"))
    }

    func testSanitizedAutomationFailureMessageRemovesFilePath() {
        let error = AppleScriptError.executionFailed(
            action: "keynote.open.present",
            message: "/Users/operator/private-show.key failed"
        )

        let message = AutomationFailureSanitizer.sanitizedMessage(from: error)

        XCTAssertFalse(message.localizedStandardContains("/Users/operator/private-show.key"))
        XCTAssertFalse(message.localizedStandardContains("private-show.key"))
    }

    func testSanitizedAutomationFailureMessageRemovesAppleScriptSource() {
        let error = AppleScriptError.executionFailed(
            action: "keynote.open.present",
            message: "tell application \"Keynote\" to open POSIX file \"/Users/operator/private-show.key\""
        )

        let message = AutomationFailureSanitizer.sanitizedMessage(from: error)

        XCTAssertFalse(message.localizedStandardContains("tell application"))
        XCTAssertFalse(message.localizedStandardContains("POSIX file"))
    }

    func testSanitizedAutomationFailureMessageKeepsFailureCategory() {
        XCTAssertEqual(
            AutomationFailureSanitizer.sanitizedMessage(from: AppleScriptError.compilationFailed(action: "keynote.open", message: "bad source")),
            "compilationFailed"
        )
        XCTAssertEqual(
            AutomationFailureSanitizer.sanitizedMessage(from: AppleScriptError.executionFailed(action: "keynote.open", message: "failed")),
            "executionFailed"
        )
        XCTAssertEqual(
            AutomationFailureSanitizer.sanitizedMessage(from: AutomationPrivacyPermissionError()),
            "permissionDenied"
        )
        XCTAssertEqual(
            AutomationFailureSanitizer.sanitizedMessage(from: AutomationPrivacyApplicationNotFoundError()),
            "applicationNotFound"
        )
    }

    func testAutomationNoticeDoesNotUseRawFailureMessage() async throws {
        let viewModel = makeViewModel()
        let finished = expectation(description: "automation command finished")
        viewModel.automationCommandDidFinishForTesting = { finished.fulfill() }
        viewModel.automationCommandRunnerForTesting = { _, action in
            throw AppleScriptError.executionFailed(
                action: action,
                message: "tell application \"Keynote\" to open POSIX file \"/Users/operator/private-show.key\""
            )
        }

        viewModel.dispatchRuntimeFacadeAction(
            .automationScriptRequested(script: privateScript, action: "keynote.open.present")
        )
        await fulfillment(of: [finished], timeout: 1)

        let notice = try XCTUnwrap(viewModel.automationRuntimeNotice)
        XCTAssertFalse(notice.title.localizedStandardContains("/Users/operator/private-show.key"))
        XCTAssertFalse(notice.message.localizedStandardContains("/Users/operator/private-show.key"))
        XCTAssertFalse(notice.title.localizedStandardContains("tell application"))
        XCTAssertFalse(notice.message.localizedStandardContains("tell application"))
    }

    func testSupportStillStoresRedactedFailureDetail() async throws {
        let viewModel = makeViewModel()
        let finished = expectation(description: "automation command finished")
        viewModel.automationCommandDidFinishForTesting = { finished.fulfill() }
        viewModel.automationCommandRunnerForTesting = { _, action in
            throw AppleScriptError.executionFailed(
                action: action,
                message: "tell application \"Keynote\" to open POSIX file \"/Users/operator/private-show.key\""
            )
        }

        viewModel.dispatchRuntimeFacadeAction(
            .automationScriptRequested(script: privateScript, action: "keynote.open.present")
        )
        await fulfillment(of: [finished], timeout: 1)

        let renderedSupport = viewModel.supportEvents.map(\.detail).joined(separator: "\n")
        XCTAssertTrue(renderedSupport.localizedStandardContains("action=keynote.open.present"))
        XCTAssertFalse(renderedSupport.localizedStandardContains("/Users/operator/private-show.key"))
        XCTAssertFalse(renderedSupport.localizedStandardContains("tell application"))
    }

    func testRuntimeActionLogDoesNotContainFailureMessage() async throws {
        let viewModel = makeViewModel()
        let finished = expectation(description: "automation command finished")
        viewModel.automationCommandDidFinishForTesting = { finished.fulfill() }
        viewModel.automationCommandRunnerForTesting = { _, action in
            throw AppleScriptError.executionFailed(
                action: action,
                message: "tell application \"Keynote\" to open POSIX file \"/Users/operator/private-show.key\""
            )
        }

        viewModel.dispatchRuntimeFacadeAction(
            .automationScriptRequested(script: privateScript, action: "keynote.open.present")
        )
        await fulfillment(of: [finished], timeout: 1)

        let renderedLog = viewModel.runtime.actionLog.map {
            "\($0.actionName)|\($0.oldStateSummary)|\($0.newStateSummary)"
        }.joined(separator: "\n")
        XCTAssertFalse(renderedLog.localizedStandardContains("/Users/operator/private-show.key"))
        XCTAssertFalse(renderedLog.localizedStandardContains("tell application"))
    }

    private var privateScript: String {
        "tell application \"Keynote\" to open POSIX file \"/Users/operator/private-show.key\""
    }

    private func makeViewModel() -> SwitcherViewModel {
        SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("docs").path) {
                return directory
            }
        }
        throw XCTSkip("Could not locate repository root from test source path.")
    }
}

private struct AutomationPrivacyPermissionError: LocalizedError {
    var errorDescription: String? {
        "Not authorized to send Apple events"
    }
}

private struct AutomationPrivacyApplicationNotFoundError: LocalizedError {
    var errorDescription: String? {
        "Application was not found"
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
