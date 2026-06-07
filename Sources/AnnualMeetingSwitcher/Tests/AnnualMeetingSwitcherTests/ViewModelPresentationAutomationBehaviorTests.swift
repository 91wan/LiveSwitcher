import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelPresentationAutomationBehaviorTests: XCTestCase {
    func testScanAndAddKeynoteWindowsDispatchesPresentationQueryRequest() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PresentationAutomation.swift"
        )
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "scanAndAddKeynoteWindows"))

        XCTAssertTrue(body.contains("operatorRequestedPresentationQuery"))
        XCTAssertTrue(body.contains("consumePresentationQueryOutcomeFromRuntime"))
        XCTAssertFalse(body.contains("scanOpenKeynoteFiles()"))
        XCTAssertFalse(body.contains("scanKeynoteWindowNames()"))
        XCTAssertFalse(body.contains("PresentationQueryResultBuilder.makeProgramItems("))
        XCTAssertFalse(body.contains("ProgramItem("))
        XCTAssertFalse(body.contains("itemsToAdd.append"))
        XCTAssertFalse(body.contains("alreadyAdded"))
        XCTAssertFalse(body.contains("KeynoteController.cleanedDocumentTitle"))
    }

    func testConsumePresentationQueryOutcomeUsesPresentationQueryResultBuilder() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PresentationAutomation.swift"
        )
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "consumePresentationQueryOutcomeFromRuntime"))

        XCTAssertTrue(body.contains("from: result"))
        XCTAssertTrue(body.contains("PresentationQueryResultBuilder.makeProgramItems("))
        XCTAssertTrue(body.contains("presentationQueryResultConsumed"))
        XCTAssertTrue(body.contains("let itemsToAdd = PresentationQueryResultBuilder.makeProgramItems("))
        XCTAssertTrue(body.contains("addProgramItems(itemsToAdd)"))
        XCTAssertTrue(body.contains("if let failure = presentationQuery.latestFailure"))
        XCTAssertFalse(body.contains("failure.id == requestID {\n            addProgramItems"))
        XCTAssertTrue(body.contains("recordSupportEvent("))
        XCTAssertTrue(body.contains("kind: .appleScriptFailed"))
        XCTAssertTrue(body.contains("dispatchRuntimeFacadeAction(.automationFailed("))
    }

    func testRuntimePortUsesPresentationQueryServiceResult() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PresentationAutomation.swift"
        )

        let helperBody = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "scanPresentationQuery"))
        XCTAssertTrue(helperBody.contains("presentationQueryService.scanPresentationQuery()"))
    }

    func testScanAndAddKeynoteWindowsStillAddsOpenKeynoteFiles() {
        let viewModel = makeViewModel()
        viewModel.testHooks.scanKeynoteWindowNames = { ["Ignored.key"] }
        viewModel.testHooks.scanOpenKeynoteFiles = { ["/tmp/show/Opening.key"] }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.programItems.map(\.title), ["Opening"])
        XCTAssertEqual(viewModel.programItems.map(\.sourceURL?.path), ["/tmp/show/Opening.key"])
    }

    func testScanAndAddKeynoteWindowsStillAddsWindowNamesWhenNoFiles() {
        let viewModel = makeViewModel()
        viewModel.testHooks.scanKeynoteWindowNames = { ["Opening.key"] }
        viewModel.testHooks.scanOpenKeynoteFiles = { [] }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.programItems.map(\.title), ["Opening"])
        XCTAssertEqual(viewModel.programItems.map(\.sourceURL), [nil])
    }

    func testScanKeynoteWindowNamesHookStillOverridesQueryService() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PresentationAutomation.swift"
        )
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "scanPresentationQuery"))

        XCTAssertTrue(body.contains("if let scanKeynoteWindowNames = testHooks.scanKeynoteWindowNames"))
        XCTAssertTrue(body.contains("windowNames = try scanKeynoteWindowNames()"))
        XCTAssertTrue(body.contains("presentationQueryService.scanKeynoteWindowNames()"))
    }

    func testScanOpenKeynoteFilesHookStillOverridesQueryService() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PresentationAutomation.swift"
        )
        let scanQueryBody = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "scanPresentationQuery"))
        let scanFilesBody = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "scanOpenKeynoteFiles"))

        XCTAssertTrue(scanQueryBody.contains("let openFilePaths = scanOpenKeynoteFiles()"))
        XCTAssertTrue(scanFilesBody.contains("if let scanOpenKeynoteFiles = testHooks.scanOpenKeynoteFiles"))
        XCTAssertTrue(scanFilesBody.contains("return scanOpenKeynoteFiles()"))
        XCTAssertTrue(scanFilesBody.contains("presentationQueryService.queryOpenKeynoteFiles()"))
    }

    private func makeViewModel(initialItems: [ProgramItem] = []) -> SwitcherViewModel {
        let suiteName = "ViewModelPresentationAutomationBehaviorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let presentationQueryPort = ClosurePresentationQueryPort()
        var state = LiveRuntimeState()
        state.program.items = initialItems
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: LiveRuntimeEffectRunner(
                recordsOnly: false,
                presentationQuery: presentationQueryPort
            ),
            environment: .productionProgramQueueOwning()
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults,
            runtime: runtime
        )
        presentationQueryPort.scanHandler = { [weak viewModel] id, context in
            guard let viewModel else { return }
            do {
                let result = try viewModel.scanPresentationQueryForRuntimePort()
                context.dispatch(.presentationQueryCompleted(id: id, result: result))
            } catch {
                context.dispatch(.presentationQueryFailed(
                    id: id,
                    action: "keynote.scan.windows",
                    sanitizedMessage: viewModel.sanitizedAutomationFailureMessage(error)
                ))
            }
        }
        viewModel.syncProgramQueueFacadeFromRuntime()
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)
        return viewModel
    }
}
