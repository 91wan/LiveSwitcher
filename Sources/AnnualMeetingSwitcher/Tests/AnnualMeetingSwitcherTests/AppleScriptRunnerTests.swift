import XCTest
@testable import LiveSwitcher

final class AppleScriptRunnerTests: XCTestCase {
    func testMalformedScriptThrowsCompilationErrorWithAction() {
        XCTAssertThrowsError(
            try AppleScriptRunner.run("tell application", action: "keynote.present.front")
        ) { error in
            guard case let AppleScriptError.compilationFailed(action, message) = error else {
                return XCTFail("Expected compilationFailed, got \(error)")
            }
            XCTAssertEqual(action, "keynote.present.front")
            XCTAssertFalse(message.isEmpty)
        }
    }

    func testErrorDescriptionKeepsActionAndMessage() {
        let error = AppleScriptError.executionFailed(
            action: "wps.open",
            message: "Application is not running"
        )

        XCTAssertEqual(
            error.errorDescription,
            "AppleScript execution failed for wps.open: Application is not running"
        )
    }

    func testViewModelDoesNotExecuteAppleScriptDirectly() throws {
        let source = try String(contentsOf: viewModelURL(), encoding: .utf8)

        XCTAssertFalse(source.contains("NSAppleScript("))
        XCTAssertFalse(source.contains("executeAndReturnError"))
    }

    @MainActor
    func testViewModelRecordsSanitizedAppleScriptFailureSupportEvent() {
        let suite = "AppleScriptRunnerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )

        viewModel.handleAppleScriptFailure(
            AppleScriptError.executionFailed(
                action: "keynote.next-slide",
                message: "/Users/operator/Show/Agenda.html failed"
            ),
            action: "keynote.next-slide"
        )

        XCTAssertEqual(viewModel.supportEvents.last?.kind, .appleScriptFailed)
        XCTAssertTrue(viewModel.supportEvents.last?.detail.contains("action=keynote.next-slide") == true)
        XCTAssertTrue(viewModel.supportEvents.last?.detail.contains("[path redacted]") == true)
        XCTAssertFalse(viewModel.supportEvents.last?.detail.localizedStandardContains("/Users/") == true)
        XCTAssertFalse(viewModel.supportEvents.last?.detail.localizedStandardContains("Agenda.html") == true)
    }

    private func viewModelURL() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate ViewModel.swift from test source path.")
    }
}
