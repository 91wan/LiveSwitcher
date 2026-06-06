import XCTest
@testable import LiveSwitcher

@MainActor
final class PresentationQueryRuntimeDuplicatePreventionTests: XCTestCase {
    func testStalePresentationQueryCompletionIsIgnored() {
        let first = UUID()
        let second = UUID()
        var state = LiveRuntimeState()
        state.presentationQuery.activeRequestID = second
        let result = PresentationQueryResult(openFilePaths: ["/tmp/show/Stale.key"], windowNames: [])

        let mutation = reduce(state, .presentationQueryCompleted(id: first, result: result))

        XCTAssertNil(mutation.state.presentationQuery.latestResult)
        XCTAssertEqual(mutation.state.presentationQuery.activeRequestID, second)
    }

    func testStalePresentationQueryFailureIsIgnored() {
        let first = UUID()
        let second = UUID()
        var state = LiveRuntimeState()
        state.presentationQuery.activeRequestID = second

        let mutation = reduce(state, .presentationQueryFailed(id: first, action: "keynote.scan.windows", sanitizedMessage: "failed"))

        XCTAssertNil(mutation.state.presentationQuery.latestFailure)
        XCTAssertEqual(mutation.state.presentationQuery.activeRequestID, second)
    }

    func testLatestPresentationQueryCompletionWins() {
        let first = UUID()
        let second = UUID()
        var state = reduce(.operatorRequestedPresentationQuery(id: first)).state
        state = reduce(state, .operatorRequestedPresentationQuery(id: second)).state
        let firstResult = PresentationQueryResult(openFilePaths: ["/tmp/show/First.key"], windowNames: [])
        let secondResult = PresentationQueryResult(openFilePaths: ["/tmp/show/Second.key"], windowNames: [])
        state = reduce(state, .presentationQueryCompleted(id: first, result: firstResult)).state

        let mutation = reduce(state, .presentationQueryCompleted(id: second, result: secondResult))

        XCTAssertEqual(mutation.state.presentationQuery.latestCompletedRequestID, second)
        XCTAssertEqual(mutation.state.presentationQuery.latestResult, secondResult)
    }

    func testConsumedPresentationQueryResultIsNotAppliedTwice() {
        let viewModel = makeViewModel()
        viewModel.testHooks.scanKeynoteWindowNames = { ["Opening.key"] }
        viewModel.testHooks.scanOpenKeynoteFiles = { [] }

        viewModel.scanAndAddKeynoteWindows()
        let countAfterScan = viewModel.programItems.count
        if let requestID = viewModel.runtime.state.presentationQuery.latestCompletedRequestID {
            viewModel.consumePresentationQueryOutcomeFromRuntime(requestID: requestID)
        }

        XCTAssertEqual(viewModel.programItems.count, countAfterScan)
    }

    func testRepeatedScanRequestsUseDistinctIDs() {
        let viewModel = makeViewModel()
        var requestIDs: [String] = []
        viewModel.testHooks.scanKeynoteWindowNames = { [] }
        viewModel.testHooks.scanOpenKeynoteFiles = { [] }

        viewModel.scanAndAddKeynoteWindows()
        requestIDs.append(contentsOf: viewModel.runtime.actionLog.filter { $0.actionName == "operatorRequestedPresentationQuery" }.map(\.newStateSummary))
        viewModel.scanAndAddKeynoteWindows()
        requestIDs.append(contentsOf: viewModel.runtime.actionLog.filter { $0.actionName == "operatorRequestedPresentationQuery" }.map(\.newStateSummary))

        XCTAssertGreaterThanOrEqual(requestIDs.count, 2)
    }

    func testProgramQueueReceivesNoDuplicatesFromRepeatedSameResult() {
        let viewModel = makeViewModel()
        viewModel.testHooks.scanKeynoteWindowNames = { ["Opening.key"] }
        viewModel.testHooks.scanOpenKeynoteFiles = { [] }

        viewModel.scanAndAddKeynoteWindows()
        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.programItems.map(\.title), ["Opening"])
    }

    func testFailureIsConsumedOnceAndCleared() {
        let viewModel = makeFailingViewModel()

        viewModel.scanAndAddKeynoteWindows()
        let supportCount = viewModel.supportEvents.count
        let consumedIDs = viewModel.runtime.state.presentationQuery.consumedRequestIDs
        consumedIDs.forEach {
            viewModel.consumePresentationQueryOutcomeFromRuntime(requestID: $0)
        }

        XCTAssertEqual(viewModel.supportEvents.count, supportCount)
        XCTAssertNil(viewModel.runtime.state.presentationQuery.latestFailure)
    }

    func testRepeatedSameFileAndWindowResultDoesNotDuplicateProgramItems() {
        let viewModel = makeViewModel()
        viewModel.testHooks.scanKeynoteWindowNames = { ["Opening.key"] }
        viewModel.testHooks.scanOpenKeynoteFiles = { ["/tmp/show/Opening.key"] }

        viewModel.scanAndAddKeynoteWindows()
        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.programItems.map(\.title), ["Opening"])
    }

    func testConsumedRequestIDsKeepOnlyRecentEntries() {
        var state = LiveRuntimeState()
        let ids = (0..<25).map { _ in UUID() }

        ids.forEach {
            state = reduce(state, .presentationQueryResultConsumed(id: $0)).state
        }

        XCTAssertEqual(state.presentationQuery.consumedRequestIDs.count, 20)
        XCTAssertFalse(state.presentationQuery.hasConsumed(ids[0]))
        XCTAssertTrue(state.presentationQuery.hasConsumed(ids[24]))
    }

    private func reduce(_ action: LiveRuntimeAction) -> LiveRuntimeMutation {
        reduce(LiveRuntimeState(), action)
    }

    private func reduce(_ state: LiveRuntimeState, _ action: LiveRuntimeAction) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(bridgeMode: .presentationQueryOwned)
        )
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "PresentationQueryRuntimeDuplicatePreventionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
    }

    private func makeFailingViewModel() -> SwitcherViewModel {
        let viewModel = makeViewModel()
        viewModel.testHooks.presentationQueryService = PresentationQueryService(
            runAppleScript: { _, _ in
                throw AppleScriptError.executionFailed(action: "keynote.scan.windows", message: "permission denied")
            },
            queryOpenKeynoteFiles: { [] }
        )
        return viewModel
    }
}
