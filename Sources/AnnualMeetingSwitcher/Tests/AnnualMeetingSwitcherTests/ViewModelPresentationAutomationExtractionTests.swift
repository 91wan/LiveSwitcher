import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelPresentationAutomationExtractionTests: XCTestCase {
    func testPresentationAutomationExtractionContract() throws {
        let mainSource = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
        let extensionSource = try XCTUnwrap(optionalRepositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PresentationAutomation.swift"
        ))

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
            XCTAssertFalse(mainSource.contains(snippet), snippet)
        }

        XCTAssertTrue(extensionSource.contains("extension SwitcherViewModel"))
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
            XCTAssertTrue(extensionSource.contains(snippet), snippet)
        }

        XCTAssertTrue(extensionSource.contains("dispatchRuntimeFacadeAction(.automationScriptRequested(script: source, action: action))"))
        XCTAssertTrue(extensionSource.contains("func keynoteNextSlide()"))
        XCTAssertTrue(extensionSource.contains("action: \"keynote.next-slide\""))
        XCTAssertTrue(extensionSource.contains("func keynotePreviousSlide()"))
        XCTAssertTrue(extensionSource.contains("action: \"keynote.previous-slide\""))
        XCTAssertTrue(extensionSource.contains("func stopDeckPresentation()"))
        XCTAssertTrue(extensionSource.contains("action: \"keynote.stop.presentation\""))
        XCTAssertTrue(extensionSource.contains("action: \"keynote.open.present\""))
        XCTAssertTrue(extensionSource.contains("private func scanKeynoteWindowNames() throws -> [String]"))
        XCTAssertTrue(extensionSource.contains("presentationQueryService.scanKeynoteWindowNames()"))
        XCTAssertTrue(extensionSource.contains("handleAppleScriptFailure(error, action: \"keynote.scan.windows\")"))
        XCTAssertTrue(extensionSource.contains("func scanOpenKeynoteFiles() -> [String]"))
        XCTAssertTrue(extensionSource.contains("presentationQueryService.queryOpenKeynoteFiles()"))
        XCTAssertTrue(extensionSource.contains("AppleScriptRunner.run(wpsScript"))
        XCTAssertTrue(extensionSource.contains("openWithWPSOffice"))
    }
}
