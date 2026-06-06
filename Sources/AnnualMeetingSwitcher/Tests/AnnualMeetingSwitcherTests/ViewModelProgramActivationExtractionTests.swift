import XCTest
@testable import LiveSwitcher

final class ViewModelProgramActivationExtractionTests: XCTestCase {
    func testProgramActivationMethodsAreNotDeclaredInProgramQueueFile() throws {
        let source = try programQueueSource()

        for forbidden in activationSnippets {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
    }

    func testProgramActivationMethodsLiveInProgramActivationExtension() throws {
        let source = try activationSource()

        XCTAssertTrue(source.contains("extension SwitcherViewModel"))
        for required in [
            "func switchToProgram(",
            "func switchToProgramAfterReadinessConfirmation(",
            "func switchToProgram(at index: Int)",
            "func toggleMainVideoPlayback(",
            "func togglePause(",
            "func seekProgramItemToStart(",
            "func restartCurrentMediaFromBeginning(",
            "func seekProgramItemToEnd("
        ] {
            XCTAssertTrue(source.contains(required), required)
        }
    }

    func testProgramQueueFileOnlyContainsQueueMutationAndAgendaPromptMethods() throws {
        let source = try programQueueSource()

        for allowed in [
            "func addProgramItem(",
            "func addProgramItems(",
            "func addAgendaMarker(",
            "func updateProgramItemSchedule(",
            "func removeProgramItem(",
            "func moveProgramItems(",
            "func agendaAutoAdvancePrompt(",
            "func dismissAgendaAutoAdvancePrompt("
        ] {
            XCTAssertTrue(source.contains(allowed), allowed)
        }
    }

    func testSwitchToProgramIsNotDeclaredInMainViewModel() throws {
        XCTAssertFalse(try viewModelSource().contains("func switchToProgram("))
    }

    func testSwitchToProgramIsNotDeclaredInProgramQueueFile() throws {
        XCTAssertFalse(try programQueueSource().contains("func switchToProgram("))
    }

    func testProgramSourceAvailabilityHelpersAreNotDeclaredInProgramQueueFile() throws {
        let source = try programQueueSource()

        XCTAssertFalse(source.contains("programSourceIsAvailable"))
        XCTAssertFalse(source.contains("handleUnavailableProgramSource"))
        XCTAssertFalse(source.contains("dispatchRuntimeProgramSelection"))
    }

    func testMediaTransportProgramMethodsAreNotDeclaredInProgramQueueFile() throws {
        let source = try programQueueSource()

        for forbidden in [
            "func toggleMainVideoPlayback(",
            "func togglePause(",
            "func seekProgramItemToStart(",
            "func restartCurrentMediaFromBeginning(",
            "func seekProgramItemToEnd(",
            "programItemSupportsSeeking"
        ] {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
    }

    func testSwitchToProgramExecutesActivationPlan() throws {
        let body = try XCTUnwrap(try activationSource().extractedRuntimeFunctionBody(named: "switchToProgram"))

        XCTAssertTrue(body.contains("ProgramActivationPlanner.plan("))
        XCTAssertTrue(body.contains("executeProgramActivationPlan(plan)"))
    }

    func testProgramActivationExecutorLivesInViewModelExtension() throws {
        XCTAssertTrue(try activationSource().contains("executeProgramActivationPlan"))
    }

    func testConfirmAgendaAutoAdvanceLivesWithActivationOrchestration() throws {
        XCTAssertFalse(try programQueueSource().contains("func confirmAgendaAutoAdvance("))
        XCTAssertTrue(try activationSource().contains("func confirmAgendaAutoAdvance("))
    }

    private var activationSnippets: [String] {
        [
            "func switchToProgram(",
            "func switchToProgramAfterReadinessConfirmation(",
            "func toggleMainVideoPlayback(",
            "func togglePause(",
            "func seekProgramItemToStart(",
            "func restartCurrentMediaFromBeginning(",
            "func seekProgramItemToEnd(",
            "programSourceIsAvailable",
            "handleUnavailableProgramSource",
            "dispatchRuntimeProgramSelection"
        ]
    }

    private func viewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }

    private func programQueueSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramQueue.swift")
    }

    private func activationSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivation.swift")
    }
}
