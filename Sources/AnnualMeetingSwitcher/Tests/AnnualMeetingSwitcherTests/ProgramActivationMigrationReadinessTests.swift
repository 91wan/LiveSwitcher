import XCTest
@testable import LiveSwitcher

final class ProgramActivationMigrationReadinessTests: XCTestCase {
    func testNoProgramActivationOwnedBridgeModeYet() throws {
        let source = try runtimeStateSource()

        XCTAssertFalse(source.contains("programActivationOwned"))
    }

    func testNoProgramActivationDomainYet() throws {
        let source = try runtimeStateSource()

        XCTAssertFalse(source.contains("case programActivation"))
    }

    func testProgramActivationStillViewModelOwned() throws {
        let docs = try repositorySource("docs/architecture/runtime-ownership.md")

        XCTAssertTrue(docs.contains("Program activation/switching side\neffects are still ViewModel-owned"))
    }

    func testProgramActivationPlannerIsPure() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/ProgramActivationPlanner.swift"
        )

        for forbidden in [
            "SwitcherViewModel",
            "LiveRuntimeStore",
            "FileManager.default",
            "recordSupportEvent",
            "dispatchRuntimeFacadeAction",
            "NSAlert"
        ] {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
    }

    func testProgramActivationExecutorLivesInViewModelExtension() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivation.swift"
        )

        XCTAssertTrue(source.contains("executeProgramActivationPlan"))
    }

    func testProgramQueueOwnedModeDoesNotOwnProgramActivation() throws {
        let source = try runtimeStateSource()

        XCTAssertFalse(source.contains(".programActivation"))
        XCTAssertTrue(LiveRuntimeBridgeMode.programQueueOwned.owns(.programQueue))
    }

    private func runtimeStateSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeState.swift")
    }
}
