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
        let viewModel = makeViewModelWithInjectedFailure()
        let requestID = try! XCTUnwrap(viewModel.runtime.state.presentationQuery.latestFailure?.id)

        viewModel.consumePresentationQueryOutcomeFromRuntime(requestID: requestID)

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .appleScriptFailed })
    }

    func testViewModelConsumesQueryFailureAndCreatesAutomationNotice() {
        let viewModel = makeViewModelWithInjectedFailure()
        let requestID = try! XCTUnwrap(viewModel.runtime.state.presentationQuery.latestFailure?.id)

        viewModel.consumePresentationQueryOutcomeFromRuntime(requestID: requestID)

        XCTAssertEqual(viewModel.automationRuntimeNotice?.action, "keynote.scan.windows")
    }

    func testViewModelConsumesQueryFailureOnlyOnce() {
        let viewModel = makeViewModelWithInjectedFailure()
        let requestID = try! XCTUnwrap(viewModel.runtime.state.presentationQuery.latestFailure?.id)

        viewModel.consumePresentationQueryOutcomeFromRuntime(requestID: requestID)
        let supportCount = viewModel.supportEvents.count
        viewModel.consumePresentationQueryOutcomeFromRuntime(requestID: requestID)

        XCTAssertEqual(viewModel.supportEvents.count, supportCount)
    }

    func testPresentationQueryFailureDoesNotExposeRawAppleScriptSource() {
        let viewModel = makeViewModel()
        let message = viewModel.sanitizedAutomationFailureMessage(
            AppleScriptError.executionFailed(
                action: "keynote.scan.windows",
                message: "tell application \"Keynote\" to open POSIX file \"/tmp/private.key\""
            )
        )

        injectPresentationQueryFailure(into: viewModel, message: message)

        XCTAssertFalse(String(describing: viewModel.runtime.state.presentationQuery.latestFailure).contains("tell application"))
    }

    private func makeViewModelWithInjectedFailure(message: String = "permission denied") -> SwitcherViewModel {
        let viewModel = makeViewModel()
        injectPresentationQueryFailure(into: viewModel, message: message)
        return viewModel
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "PresentationQueryRuntimeFailureTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let runtime = LiveRuntimeStore(
            effectRunner: .recording(),
            environment: .productionProgramQueueOwning()
        )
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults,
            runtime: runtime
        )
    }

    private func injectPresentationQueryFailure(
        into viewModel: SwitcherViewModel,
        requestID: UUID = UUID(),
        message: String
    ) {
        var state = viewModel.runtime.state
        state.presentationQuery.activeRequestID = nil
        state.presentationQuery.latestCompletedRequestID = nil
        state.presentationQuery.latestResult = nil
        state.presentationQuery.latestFailure = PresentationQueryFailure(
            id: requestID,
            action: "keynote.scan.windows",
            sanitizedMessage: message
        )
        viewModel.runtime.replaceStateForFacadeSync(state)
    }
}
