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

    func testViewModelConsumesQueryFailureAndRecordsSupport() throws {
        let body = try consumePresentationQueryOutcomeBody()

        XCTAssertTrue(body.contains("recordSupportEvent("))
        XCTAssertTrue(body.contains("kind: .appleScriptFailed"))
    }

    func testViewModelConsumesQueryFailureAndCreatesAutomationNotice() throws {
        let body = try consumePresentationQueryOutcomeBody()

        XCTAssertTrue(body.contains("dispatchRuntimeFacadeAction(.automationFailed("))
    }

    func testViewModelConsumesQueryFailureOnlyOnce() throws {
        let body = try consumePresentationQueryOutcomeBody()

        XCTAssertTrue(body.contains("guard !presentationQuery.hasConsumed(requestID) else { return }"))
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

    private func consumePresentationQueryOutcomeBody() throws -> String {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PresentationAutomation.swift"
        )
        return try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "consumePresentationQueryOutcomeFromRuntime"))
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
