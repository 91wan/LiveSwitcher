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

    func testScanAndAddKeynoteWindowsStillNoopsOnScanFailure() {
        let viewModel = makeViewModel()
        let requestID = UUID()
        injectPresentationQueryFailure(into: viewModel, requestID: requestID, message: "failed")

        viewModel.consumePresentationQueryOutcomeFromRuntime(requestID: requestID)

        XCTAssertTrue(viewModel.programItems.isEmpty)
    }

    func testScanFailureStillRecordsSupportAndAutomationNotice() {
        let viewModel = makeViewModel()
        let requestID = UUID()
        injectPresentationQueryFailure(into: viewModel, requestID: requestID, message: "permission denied")

        viewModel.consumePresentationQueryOutcomeFromRuntime(requestID: requestID)

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .appleScriptFailed })
        XCTAssertEqual(viewModel.automationRuntimeNotice?.action, "keynote.scan.windows")
    }

    func testScanKeynoteWindowNamesHookStillOverridesQueryService() {
        let viewModel = makeViewModel()
        viewModel.testHooks.presentationQueryService = PresentationQueryService(
            runAppleScript: { _, _ in
                throw AppleScriptError.executionFailed(action: "keynote.scan.windows", message: "should not run")
            },
            queryOpenKeynoteFiles: { [] }
        )
        viewModel.testHooks.scanKeynoteWindowNames = { ["Opening.key"] }
        viewModel.testHooks.scanOpenKeynoteFiles = { [] }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.programItems.map(\.title), ["Opening"])
    }

    func testScanOpenKeynoteFilesHookStillOverridesQueryService() {
        let viewModel = makeViewModel()
        viewModel.testHooks.presentationQueryService = PresentationQueryService(
            runAppleScript: { _, _ in NSAppleEventDescriptor(string: "Ignored.key") },
            queryOpenKeynoteFiles: { ["/tmp/show/Ignored.key"] }
        )
        viewModel.testHooks.scanOpenKeynoteFiles = { ["/tmp/show/Opening.key"] }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.programItems.map(\.title), ["Opening"])
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

    private func injectPresentationQueryFailure(
        into viewModel: SwitcherViewModel,
        requestID: UUID,
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
