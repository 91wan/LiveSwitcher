import XCTest

final class ViewModelProjectionOutputExtractionTests: XCTestCase {
    func testProjectionOutputMethodsAreNotDeclaredInMainViewModel() throws {
        let source = try mainViewModelSource()

        [
            "func handleBroadcastToggle(",
            "func showOutputWindowFromRuntimeProjection(",
            "func hideOutputWindowFromRuntimeProjection(",
            "func handleExternalDisplayLost(",
            "func refreshExternalDisplayAvailability("
        ].forEach { marker in
            XCTAssertFalse(source.contains(marker), "\(marker) should live in ViewModel+ProjectionOutput.swift")
        }
    }

    func testProjectionOutputMethodsLiveInProjectionOutputExtension() throws {
        let source = try XCTUnwrap(
            optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProjectionOutput.swift")
        )

        [
            "func handleBroadcastToggle(",
            "func showOutputWindowFromRuntimeProjection(",
            "func hideOutputWindowFromRuntimeProjection(",
            "func handleExternalDisplayLost(",
            "func refreshExternalDisplayAvailability("
        ].forEach { marker in
            XCTAssertTrue(source.contains(marker), "\(marker) should live in ViewModel+ProjectionOutput.swift")
        }
    }

    func testExternalDisplayObserverSetupIsNotDeclaredInMainViewModel() throws {
        let source = try mainViewModelSource()

        XCTAssertFalse(source.contains("func setupExternalDisplayObserver("))
    }

    func testProjectionSupportHelpersAreNotDeclaredInMainViewModel() throws {
        let source = try mainViewModelSource()

        XCTAssertFalse(source.contains("recordProjectionSupportAfterRuntime"))
    }

    func testOutputWindowSideEffectsAreNotDeclaredInMainViewModel() throws {
        let source = try mainViewModelSource()

        XCTAssertFalse(source.contains("outputWindowController?.mountAnyView"))
        XCTAssertFalse(source.contains("outputWindowController?.show"))
        XCTAssertFalse(source.contains("outputWindowController?.hide"))
    }

    private func mainViewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }
}
