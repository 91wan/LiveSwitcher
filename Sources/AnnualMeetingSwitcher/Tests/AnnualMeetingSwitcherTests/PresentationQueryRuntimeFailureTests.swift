import XCTest
@testable import LiveSwitcher

@MainActor
final class PresentationQueryRuntimeFailureTests: XCTestCase {
    func testPresentationQueryFailureStoresSanitizedMessage() {
        let id = UUID()
        var state = LiveRuntimeState()
        state.presentationQuery.activeRequestID = id

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .presentationQueryFailed(id: id, action: "keynote.scan.windows", sanitizedMessage: "permissionDenied"),
            environment: LiveRuntimeEnvironment(bridgeMode: .presentationQueryOwned)
        )

        XCTAssertEqual(mutation.state.presentationQuery.latestFailure?.sanitizedMessage, "permissionDenied")
    }

    func testPresentationQueryFailureDoesNotWriteSupportInReducer() {
        let id = UUID()
        var state = LiveRuntimeState()
        state.presentationQuery.activeRequestID = id

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .presentationQueryFailed(id: id, action: "keynote.scan.windows", sanitizedMessage: "failed"),
            environment: LiveRuntimeEnvironment(bridgeMode: .presentationQueryOwned)
        )

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    func testViewModelConsumesQueryFailureAndRecordsSupport() {
        let viewModel = makeFailingViewModel()

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .appleScriptFailed })
    }

    func testViewModelConsumesQueryFailureAndCreatesAutomationNotice() {
        let viewModel = makeFailingViewModel()

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.automationRuntimeNotice?.action, "keynote.scan.windows")
    }

    func testViewModelConsumesQueryFailureOnlyOnce() {
        let viewModel = makeFailingViewModel()

        viewModel.scanAndAddKeynoteWindows()
        let supportCount = viewModel.supportEvents.count
        if let requestID = viewModel.runtime.state.presentationQuery.latestFailure?.id {
            viewModel.consumePresentationQueryOutcomeFromRuntime(requestID: requestID)
        }

        XCTAssertEqual(viewModel.supportEvents.count, supportCount)
    }

    func testPresentationQueryFailureDoesNotExposeRawAppleScriptSource() {
        let viewModel = makeFailingViewModel(message: "tell application \"Keynote\" to open POSIX file \"/tmp/private.key\"")

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertFalse(String(describing: viewModel.runtime.state.presentationQuery.latestFailure).contains("tell application"))
    }

    private func makeFailingViewModel(message: String = "permission denied") -> SwitcherViewModel {
        let viewModel = makeViewModel()
        viewModel.testHooks.presentationQueryService = PresentationQueryService(
            runAppleScript: { _, _ in
                throw AppleScriptError.executionFailed(action: "keynote.scan.windows", message: message)
            },
            queryOpenKeynoteFiles: { [] }
        )
        return viewModel
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "PresentationQueryRuntimeFailureTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
    }
}
