import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramQueueRuntimePresentationQueryIntegrationTests: XCTestCase {
    func testPresentationQuerySuccessAddsItemsThroughRuntimeProgramQueueAction() {
        let viewModel = makeViewModel()
        viewModel.testHooks.scanKeynoteWindowNames = { [] }
        viewModel.testHooks.scanOpenKeynoteFiles = { ["/tmp/show/Opening.key"] }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorAddedProgramItems" })
    }

    func testPresentationQuerySuccessDoesNotAppendProgramItemsDirectly() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+PresentationAutomation.swift"
        )
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "consumePresentationQueryOutcomeFromRuntime"))

        XCTAssertTrue(body.contains("addProgramItems(itemsToAdd)"))
        XCTAssertFalse(body.contains("programItems.append"))
    }

    func testPresentationQuerySuccessSyncsProgramQueueFacade() {
        let viewModel = makeViewModel()
        viewModel.testHooks.scanKeynoteWindowNames = { [] }
        viewModel.testHooks.scanOpenKeynoteFiles = { ["/tmp/show/Opening.key"] }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.programItems.map(\.title), ["Opening"])
    }

    func testPresentationQuerySuccessSyncsRuntimeProgramQueue() {
        let viewModel = makeViewModel()
        viewModel.testHooks.scanKeynoteWindowNames = { [] }
        viewModel.testHooks.scanOpenKeynoteFiles = { ["/tmp/show/Opening.key"] }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.runtime.state.program.items.map(\.title), ["Opening"])
    }

    func testPresentationQueryConsumedAfterProgramQueueSync() {
        let viewModel = makeViewModel()
        viewModel.testHooks.scanKeynoteWindowNames = { [] }
        viewModel.testHooks.scanOpenKeynoteFiles = { ["/tmp/show/Opening.key"] }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertNil(viewModel.runtime.state.presentationQuery.latestCompletedRequestID)
        XCTAssertNil(viewModel.runtime.state.presentationQuery.latestResult)
        XCTAssertEqual(viewModel.runtime.state.program.items.map(\.title), ["Opening"])
    }

    func testRepeatedPresentationQueryResultDoesNotDuplicateRuntimeQueueItems() {
        let viewModel = makeViewModel()
        viewModel.testHooks.scanKeynoteWindowNames = { ["Opening.key"] }
        viewModel.testHooks.scanOpenKeynoteFiles = { ["/tmp/show/Opening.key"] }

        viewModel.scanAndAddKeynoteWindows()
        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.runtime.state.program.items.map(\.title), ["Opening"])
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "ProgramQueueRuntimePresentationQueryIntegrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
    }
}
