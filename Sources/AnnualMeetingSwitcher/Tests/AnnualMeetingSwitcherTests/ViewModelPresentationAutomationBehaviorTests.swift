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
        let scanFilesBody = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "scanOpenKeynoteFiles"))

        XCTAssertTrue(helperBody.contains("if let scanKeynoteWindowNames = testHooks.scanKeynoteWindowNames"))
        XCTAssertTrue(helperBody.contains("windowNames = try scanKeynoteWindowNames()"))
        XCTAssertTrue(helperBody.contains("presentationQueryService.scanKeynoteWindowNames()"))
        XCTAssertTrue(helperBody.contains("let openFilePaths = scanOpenKeynoteFiles()"))
        XCTAssertTrue(scanFilesBody.contains("if let scanOpenKeynoteFiles = testHooks.scanOpenKeynoteFiles"))
        XCTAssertTrue(scanFilesBody.contains("return scanOpenKeynoteFiles()"))
        XCTAssertTrue(scanFilesBody.contains("presentationQueryService.queryOpenKeynoteFiles()"))
    }

}
