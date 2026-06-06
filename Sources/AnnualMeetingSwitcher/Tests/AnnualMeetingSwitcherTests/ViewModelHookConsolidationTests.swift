import XCTest

final class ViewModelHookConsolidationTests: XCTestCase {
    func testLooseProductionActionHandlerFieldsAreRemovedFromMainViewModel() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")

        [
            "var keynotePresentationHandler",
            "var pptxOpenHandler",
            "var deckStopHandler",
            "var programSeekToStartHandler",
            "var programRestartFromBeginningHandler",
            "var programSeekToEndHandler",
            "var activeDeckPresentationHandler",
            "var invalidDeckHandler"
        ].forEach { snippet in
            XCTAssertFalse(source.contains(snippet), snippet)
        }
    }

    func testLooseTestHookFieldsAreRemovedFromMainViewModel() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")

        [
            "var pageInterceptStartOverride",
            "var scanOpenKeynoteFilesForTesting",
            "var scanKeynoteWindowNamesForTesting",
            "var automationCommandRunnerForTesting",
            "var automationCommandDidFinishForTesting",
            "var saveDataDidRun"
        ].forEach { snippet in
            XCTAssertFalse(source.contains(snippet), snippet)
        }
    }

    func testProjectionReadFacadeRemainsInMainOnlyToPreservePrivateState() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")

        XCTAssertTrue(source.contains("private(set) var isExternalDisplayAvailable"))
        XCTAssertTrue(source.contains("var projectionService: ProjectionService"))
        XCTAssertTrue(source.contains("var hasExternalDisplay: Bool"))
    }
}
