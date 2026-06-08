import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramQueueMigrationReadinessTests: XCTestCase {
    func testRuntimeIntroducesProgramQueueOwnershipStage() throws {
        let state = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeState.swift"
        )
        let action = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift"
        )

        XCTAssertTrue(state.contains("programQueueOwned"))
        XCTAssertTrue(state.contains("case programQueue"))
        XCTAssertTrue(action.contains("operatorAddedProgramItems"))
        XCTAssertTrue(action.contains("operatorRemovedProgramItem"))
        XCTAssertTrue(action.contains("operatorMovedProgramItems"))
    }

    func testViewModelQueueMutationMethodsDispatchRuntimeActions() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramQueue.swift"
        )

        XCTAssertTrue(source.contains("func addProgramItems(_ items: [ProgramItem])"))
        XCTAssertTrue(source.contains("dispatchRuntimeFacadeAction(.operatorAddedProgramItems"))
        XCTAssertTrue(source.contains("dispatchRuntimeFacadeAction(.operatorRemovedProgramItem"))
        XCTAssertTrue(source.contains("dispatchRuntimeFacadeAction(.operatorMovedProgramItems"))
        XCTAssertFalse(source.contains("programItems.append(contentsOf:"))
        XCTAssertFalse(source.contains("programItems.removeAll"))
        XCTAssertFalse(source.contains("programItems.move(fromOffsets:"))
    }

    func testPresentationQueryRuntimePortDoesNotMutateProgramQueue() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeWiring.swift"
        )
        let handler = try XCTUnwrap(source.presentationQueryScanHandlerBody())

        XCTAssertFalse(handler.contains("addProgramItems"))
        XCTAssertFalse(handler.contains("programItems"))
    }

    func testPresentationQuerySuccessAppliesProgramQueueThroughViewModelOnly() {
        let viewModel = makeViewModel()
        viewModel.testHooks.scanKeynoteWindowNames = { [] }
        viewModel.testHooks.scanOpenKeynoteFiles = { ["/tmp/show/Opening.key"] }

        viewModel.scanAndAddKeynoteWindows()

        XCTAssertEqual(viewModel.programItems.map(\.title), ["Opening"])
        XCTAssertEqual(viewModel.runtime.state.program.items.map(\.title), ["Opening"])
    }

    func testProgramActivationMethodsRemainViewModelOwned() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivation.swift"
        )

        XCTAssertTrue(source.contains("programSourceIsAvailable"))
        XCTAssertTrue(source.contains("programActivationSideEffects.presentInvalidDeckAlert"))
        XCTAssertTrue(source.contains("programActivationSideEffects.presentKeynote"))
        XCTAssertTrue(source.contains("programActivationSideEffects.openPPTX"))
        XCTAssertTrue(source.contains("openHTMLInOutputWindow"))
        XCTAssertTrue(source.contains("programActivationSideEffects.presentActiveDeck"))
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "ProgramQueueMigrationReadinessTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
    }
}

private extension String {
    func presentationQueryScanHandlerBody() -> String? {
        guard let assignment = range(of: "ports.presentationQueryPort.scanHandler =") else { return nil }
        guard let openingBrace = self[assignment.upperBound...].firstIndex(of: "{") else { return nil }
        return balancedPresentationQueryBody(startingAt: openingBrace)
    }

    func balancedPresentationQueryBody(startingAt openingBrace: String.Index) -> String? {
        var depth = 0
        var index = openingBrace
        while index < endIndex {
            if self[index] == "{" {
                depth += 1
            } else if self[index] == "}" {
                depth -= 1
                if depth == 0 {
                    return String(self[openingBrace...index])
                }
            }
            index = self.index(after: index)
        }
        return nil
    }
}
