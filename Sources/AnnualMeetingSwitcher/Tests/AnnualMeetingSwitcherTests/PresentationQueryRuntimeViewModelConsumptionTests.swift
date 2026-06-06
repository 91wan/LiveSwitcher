import XCTest
@testable import LiveSwitcher

@MainActor
final class PresentationQueryRuntimeViewModelConsumptionTests: XCTestCase {
    func testScanAndAddKeynoteWindowsDispatchesRuntimePresentationQueryRequest() {
        let viewModel = makeViewModel()
        viewModel.testHooks.scanKeynoteWindowNames = { [] }
        viewModel.testHooks.scanOpenKeynoteFiles = { [] }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorRequestedPresentationQuery" })
    }

    func testScanAndAddKeynoteWindowsConsumesRuntimeQuerySuccess() {
        let viewModel = makeViewModel()
        viewModel.testHooks.scanKeynoteWindowNames = { [] }
        viewModel.testHooks.scanOpenKeynoteFiles = { ["/tmp/show/Opening.key"] }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.programItems.map(\.title), ["Opening"])
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "presentationQueryResultConsumed" })
    }

    func testScanAndAddKeynoteWindowsAddsOpenKeynoteFilesFromRuntimeResult() {
        let viewModel = makeViewModel()
        viewModel.testHooks.scanKeynoteWindowNames = { ["Ignored.key"] }
        viewModel.testHooks.scanOpenKeynoteFiles = { ["/tmp/show/Opening.key"] }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.programItems.map(\.title), ["Opening"])
        XCTAssertEqual(viewModel.programItems.map(\.sourceURL?.path), ["/tmp/show/Opening.key"])
    }

    func testScanAndAddKeynoteWindowsAddsWindowNamesWhenNoFilesFromRuntimeResult() {
        let viewModel = makeViewModel()
        viewModel.testHooks.scanKeynoteWindowNames = { ["Opening.key"] }
        viewModel.testHooks.scanOpenKeynoteFiles = { [] }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.programItems.map(\.title), ["Opening"])
        XCTAssertEqual(viewModel.programItems.map(\.sourceURL), [nil])
    }

    func testScanAndAddKeynoteWindowsMarksRuntimeResultConsumed() {
        let viewModel = makeViewModel()
        viewModel.testHooks.scanKeynoteWindowNames = { ["Opening.key"] }
        viewModel.testHooks.scanOpenKeynoteFiles = { [] }

        viewModel.scanAndAddKeynoteWindows()

        let latestID = try? XCTUnwrap(viewModel.runtime.state.presentationQuery.latestCompletedRequestID)
        XCTAssertTrue(latestID.map { viewModel.runtime.state.presentationQuery.consumedRequestIDs.contains($0) } ?? false)
    }

    func testScanAndAddKeynoteWindowsDoesNotApplyConsumedResultTwice() {
        let viewModel = makeViewModel()
        viewModel.testHooks.scanKeynoteWindowNames = { ["Opening.key"] }
        viewModel.testHooks.scanOpenKeynoteFiles = { [] }

        viewModel.scanAndAddKeynoteWindows()
        let countAfterFirstScan = viewModel.programItems.count
        if let requestID = viewModel.runtime.state.presentationQuery.latestCompletedRequestID {
            viewModel.consumePresentationQueryOutcomeFromRuntime(requestID: requestID)
        }

        XCTAssertEqual(viewModel.programItems.count, countAfterFirstScan)
    }

    func testScanAndAddKeynoteWindowsDoesNotMutateProgramQueueFromPort() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeWiring.swift"
        )
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "configureRuntimePortHandlers"))

        XCTAssertFalse(body.contains("addProgramItems("))
        XCTAssertFalse(body.contains("recordSupportEvent("))
        XCTAssertFalse(body.contains("showAutomationRuntimeNotice("))
    }

    func testScanAndAddKeynoteWindowsDoesNotCallPresentationQueryServiceDirectly() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PresentationAutomation.swift"
        )
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "scanAndAddKeynoteWindows"))

        XCTAssertTrue(body.contains("operatorRequestedPresentationQuery"))
        XCTAssertTrue(body.contains("consumePresentationQueryOutcomeFromRuntime"))
        XCTAssertFalse(body.contains("presentationQueryService.scanPresentationQuery()"))
        XCTAssertFalse(body.contains("scanKeynoteWindowNames()"))
        XCTAssertFalse(body.contains("scanOpenKeynoteFiles()"))
        XCTAssertFalse(body.contains("PresentationQueryResultBuilder.makeProgramItems("))
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "PresentationQueryRuntimeViewModelConsumptionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
    }
}
