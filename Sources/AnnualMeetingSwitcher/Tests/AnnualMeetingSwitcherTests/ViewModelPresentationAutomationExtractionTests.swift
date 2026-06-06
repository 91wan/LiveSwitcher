import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelPresentationAutomationExtractionTests: XCTestCase {
    func testPresentationAutomationMethodsAreNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()
        let forbiddenSnippets = [
            "func openAndPresentKeynote(",
            "func openPPTXWithKeynote(",
            "func presentFrontKeynoteDocument(",
            "func keynoteNextSlide(",
            "func keynotePreviousSlide(",
            "func scanKeynoteWindowNames(",
            "func scanOpenKeynoteFiles(",
            "func scanAndAddKeynoteWindows(",
            "private func runAutomationScript("
        ]

        for snippet in forbiddenSnippets {
            XCTAssertFalse(source.contains(snippet), snippet)
        }
    }

    func testPresentationAutomationMethodsLiveInPresentationAutomationExtension() throws {
        let source = try XCTUnwrap(presentationAutomationExtensionSource())

        XCTAssertTrue(source.contains("extension SwitcherViewModel"))
        for snippet in [
            "func openAndPresentKeynote(",
            "func openPPTXWithKeynote(",
            "func presentFrontKeynoteDocument(",
            "func keynoteNextSlide(",
            "func keynotePreviousSlide(",
            "func stopDeckPresentation(",
            "func scanKeynoteWindowNames(",
            "func scanOpenKeynoteFiles(",
            "func scanAndAddKeynoteWindows(",
            "func runAutomationScript("
        ] {
            XCTAssertTrue(source.contains(snippet), snippet)
        }
    }

    func testRunAutomationScriptStillDispatchesRuntimeAction() throws {
        let body = try functionBody("runAutomationScript")

        XCTAssertTrue(body.contains("dispatchRuntimeFacadeAction(.automationScriptRequested(script: source, action: action))"))
    }

    func testKeynoteNextSlideStillUsesRuntimeAutomationCommand() throws {
        XCTAssertTrue(try functionBody("keynoteNextSlide").contains("runAutomationScript("))
    }

    func testKeynotePreviousSlideStillUsesRuntimeAutomationCommand() throws {
        XCTAssertTrue(try functionBody("keynotePreviousSlide").contains("runAutomationScript("))
    }

    func testStopDeckPresentationStillUsesRuntimeAutomationCommand() throws {
        XCTAssertTrue(try functionBody("stopDeckPresentation").contains("runAutomationScript("))
    }

    func testOpenAndPresentKeynoteStillUsesRuntimeAutomationCommand() throws {
        XCTAssertTrue(try functionBody("openAndPresentKeynote").contains("runAutomationScript("))
    }

    func testScanKeynoteWindowNamesRemainsViewModelOwned() throws {
        let body = try functionBody("scanKeynoteWindowNames")

        XCTAssertTrue(body.contains("presentationQueryService.scanKeynoteWindowNames()"))
        XCTAssertTrue(body.contains("handleAppleScriptFailure(error, action: \"keynote.scan.windows\")"))
        XCTAssertFalse(body.contains(".automationScriptRequested"))
    }

    func testScanOpenKeynoteFilesRemainsViewModelOwned() throws {
        let body = try functionBody("scanOpenKeynoteFiles")

        XCTAssertTrue(body.contains("presentationQueryService.queryOpenKeynoteFiles()"))
        XCTAssertFalse(body.contains(".automationScriptRequested"))
    }

    func testOpenPPTXWPSFallbackBranchRemainsViewModelOwned() throws {
        let body = try functionBody("openPPTXWithKeynote")

        XCTAssertTrue(body.contains("AppleScriptRunner.run(wpsScript"))
        XCTAssertTrue(body.contains("openWithWPSOffice"))
        XCTAssertFalse(body.contains(".automationScriptRequested"))
    }

    func testNoResultReturningQueryDispatchesAutomationScriptRequested() throws {
        for name in ["scanKeynoteWindowNames", "scanOpenKeynoteFiles", "openPPTXWithKeynote"] {
            XCTAssertFalse(try functionBody(name).contains(".automationScriptRequested"), name)
        }
    }

    private func viewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }

    private func presentationAutomationExtensionSource() throws -> String? {
        try optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PresentationAutomation.swift")
    }

    private func functionBody(_ name: String) throws -> String {
        let source = try XCTUnwrap(presentationAutomationExtensionSource())
        return try XCTUnwrap(source.extractedRuntimeFunctionBody(named: name))
    }
}
