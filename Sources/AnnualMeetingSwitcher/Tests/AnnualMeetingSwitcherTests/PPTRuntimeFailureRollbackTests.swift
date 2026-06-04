import XCTest
@testable import LiveSwitcher

@MainActor
final class PPTRuntimeFailureRollbackTests: XCTestCase {
    func testPPTStartFailureRollsBackRuntimeState() {
        let viewModel = makeViewModel()
        viewModel.pageInterceptStartOverride = { false }

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertFalse(viewModel.runtime.state.ppt.isRequested)
        XCTAssertFalse(viewModel.runtime.state.ppt.isEventTapActive)
        XCTAssertEqual(viewModel.runtime.state.ppt.lastFailureReason, "overrideFailed")
    }

    func testPPTStartFailureRollsBackFacadeState() {
        let viewModel = makeViewModel()
        viewModel.pageInterceptStartOverride = { false }

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertFalse(viewModel.isPageInterceptEnabled)
    }

    func testPPTStartFailureDoesNotRecordSuccessEvent() {
        let viewModel = makeViewModel()
        viewModel.pageInterceptStartOverride = { false }

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .pageInterceptEnabled })
        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .pptModeChanged && $0.detail.contains("isOn=true") })
    }

    func testPPTStartPermissionFailureCanStillPresentAlert() throws {
        let source = try sourceText("ViewModel.swift")

        XCTAssertTrue(source.contains("presentAutomationAlert("))
        XCTAssertTrue(source.contains("accessibilityPermission"))
    }

    func testPPTStartOverrideFailureDoesNotLeaveRequestedTrue() {
        let viewModel = makeViewModel()
        viewModel.pageInterceptStartOverride = { false }

        viewModel.setPPTMode(true, source: .command)

        XCTAssertFalse(viewModel.runtime.state.ppt.isRequested)
    }

    func testPPTStartSideEffectsDisabledPathCanSucceedForTests() {
        let viewModel = makeViewModel()
        viewModel.pageInterceptSideEffectsEnabled = false

        viewModel.setPPTMode(true, source: .liveMode)

        XCTAssertTrue(viewModel.runtime.state.ppt.isEventTapActive)
        XCTAssertTrue(viewModel.isPageInterceptEnabled)
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "PPTRuntimeFailureRollbackTests.\(UUID().uuidString)"
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
