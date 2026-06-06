import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramQueueMigrationReadinessTests: XCTestCase {
    func testRuntimeDoesNotIntroduceProgramQueueOwnershipYet() throws {
        let state = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeState.swift"
        )
        let action = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeAction.swift"
        )

        XCTAssertFalse(state.contains("programQueueOwned"))
        XCTAssertFalse(action.contains("operatorAddedProgramItems"))
        XCTAssertFalse(action.contains("operatorRemovedProgramItem"))
        XCTAssertFalse(action.contains("operatorMovedProgramItems"))
    }

    func testViewModelStillOwnsProgramQueueMutation() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramQueue.swift"
        )

        XCTAssertTrue(source.contains("func addProgramItems(_ items: [ProgramItem])"))
        XCTAssertTrue(source.contains("programItems.append(contentsOf: items)"))
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
