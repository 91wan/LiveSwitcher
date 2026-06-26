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
            "func handleAgendaReminderAction(",
            "programSourceIsAvailable"
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
            "func agendaReminderPrompt(",
            "func acknowledgeAgendaReminder("
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
        XCTAssertFalse(source.contains("ProgramSourceAvailabilityPolicy"))
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

    func testSwitchToProgramRequestsRuntimeActivationAfterPlanning() throws {
        let body = try XCTUnwrap(try activationSource().extractedRuntimeFunctionBody(named: "switchToProgram"))

        XCTAssertTrue(body.contains("programSourceIsAvailable(activationItem)"))
        XCTAssertTrue(body.contains("ProgramActivationPlanner.plan("))
        XCTAssertTrue(body.contains(".operatorRequestedProgramActivation"))
    }

    func testProgramActivationExecutorLivesInRuntimeBridgeExtension() throws {
        XCTAssertTrue(try activationRuntimeBridgeSource().contains("executeProgramActivationPlanFromRuntime"))
    }

    func testAgendaReminderActionLivesWithActivationOrchestration() throws {
        XCTAssertFalse(try programQueueSource().contains("func handleAgendaReminderAction("))
        XCTAssertTrue(try activationSource().contains("func handleAgendaReminderAction("))
    }

    private var activationSnippets: [String] {
        [
            "func switchToProgram(",
            "func switchToProgramAfterReadinessConfirmation(",
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

    private func activationRuntimeBridgeSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivationRuntimeBridge.swift")
    }
}
