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
        let source = try XCTUnwrap(presentationAutomationExtensionSource())

        XCTAssertTrue(source.contains("func runAutomationScript("))
        XCTAssertTrue(source.contains("dispatchRuntimeFacadeAction(.automationScriptRequested(script: source, action: action))"))
    }

    func testKeynoteNextSlideStillUsesRuntimeAutomationCommand() throws {
        let source = try XCTUnwrap(presentationAutomationExtensionSource())

        XCTAssertTrue(source.contains("func keynoteNextSlide()"))
        XCTAssertTrue(source.contains("action: \"keynote.next-slide\""))
    }

    func testKeynotePreviousSlideStillUsesRuntimeAutomationCommand() throws {
        let source = try XCTUnwrap(presentationAutomationExtensionSource())

        XCTAssertTrue(source.contains("func keynotePreviousSlide()"))
        XCTAssertTrue(source.contains("action: \"keynote.previous-slide\""))
    }

    func testStopDeckPresentationStillUsesRuntimeAutomationCommand() throws {
        let source = try XCTUnwrap(presentationAutomationExtensionSource())

        XCTAssertTrue(source.contains("func stopDeckPresentation()"))
        XCTAssertTrue(source.contains("action: \"keynote.stop.presentation\""))
    }

    func testOpenAndPresentKeynoteStillUsesRuntimeAutomationCommand() throws {
        let source = try XCTUnwrap(presentationAutomationExtensionSource())

        XCTAssertTrue(source.contains("func openAndPresentKeynote("))
        XCTAssertTrue(source.contains("action: \"keynote.open.present\""))
    }

    func testScanKeynoteWindowNamesRemainsViewModelOwned() throws {
        let source = try XCTUnwrap(presentationAutomationExtensionSource())

        XCTAssertTrue(source.contains("private func scanKeynoteWindowNames() throws -> [String]"))
        XCTAssertTrue(source.contains("presentationQueryService.scanKeynoteWindowNames()"))
        XCTAssertTrue(source.contains("handleAppleScriptFailure(error, action: \"keynote.scan.windows\")"))
    }

    func testScanOpenKeynoteFilesRemainsViewModelOwned() throws {
        let source = try XCTUnwrap(presentationAutomationExtensionSource())

        XCTAssertTrue(source.contains("func scanOpenKeynoteFiles() -> [String]"))
        XCTAssertTrue(source.contains("presentationQueryService.queryOpenKeynoteFiles()"))
    }

    func testOpenPPTXWPSFallbackBranchRemainsViewModelOwned() throws {
        let source = try XCTUnwrap(presentationAutomationExtensionSource())

        XCTAssertTrue(source.contains("func openPPTXWithKeynote("))
        XCTAssertTrue(source.contains("AppleScriptRunner.run(wpsScript"))
        XCTAssertTrue(source.contains("openWithWPSOffice"))
    }

    func testNoResultReturningQueryDispatchesAutomationScriptRequested() throws {
        let source = try XCTUnwrap(presentationAutomationExtensionSource())

        XCTAssertTrue(source.contains("func runAutomationScript("))
        XCTAssertTrue(source.contains("private func scanKeynoteWindowNames() throws -> [String]"))
        XCTAssertTrue(source.contains("func scanOpenKeynoteFiles() -> [String]"))
        XCTAssertTrue(source.contains("func openPPTXWithKeynote("))
    }

    private func viewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }

    private func presentationAutomationExtensionSource() throws -> String? {
        try optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PresentationAutomation.swift")
    }

}
