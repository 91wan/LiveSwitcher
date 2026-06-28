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

    func testProjectionReadFacadeLivesInFocusedAccessorExtension() throws {
        let root = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
        let extensionSource = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProjectionAccessors.swift"
        )

        XCTAssertNotNil(root.range(of: "private(set) var isExternalDisplayAvailable"))
        XCTAssertNil(root.range(of: "var projectionService: ProjectionService"))
        XCTAssertNil(root.range(of: "var hasExternalDisplay: Bool"))
        XCTAssertNotNil(extensionSource.range(of: "var projectionService: ProjectionService"))
        XCTAssertNotNil(extensionSource.range(of: "var hasExternalDisplay: Bool"))
    }
}
