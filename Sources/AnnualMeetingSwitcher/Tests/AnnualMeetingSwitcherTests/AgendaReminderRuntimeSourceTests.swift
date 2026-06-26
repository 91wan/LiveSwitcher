import XCTest
@testable import LiveSwitcher

@MainActor
final class AgendaReminderRuntimeSourceTests: XCTestCase {
    func testAgendaReminderPromptUsesRuntimePreferenceWhenPersistenceOwned() throws {
        let current = scheduledProgram("Current", start: 0)
        let next = scheduledProgram("Next", start: 100)
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            runtimeItems: [current, next],
            runtimeCurrent: current,
            runtimeAgendaReminder: true,
            facadeItems: [current, next],
            facadeCurrent: current,
            facadeAgendaReminder: false
        )

        let prompt = viewModel.agendaReminderPrompt(now: Date(timeIntervalSince1970: 120))

        XCTAssertEqual(prompt?.itemID, next.id)
    }

    func testAgendaReminderPromptUsesFacadePreferenceBeforePersistenceOwnership() {
        let current = scheduledProgram("Current", start: 0)
        let next = scheduledProgram("Next", start: 100)
        let viewModel = makeViewModel(
            bridgeMode: .recordingOnly,
            runtimeItems: [current, next],
            runtimeCurrent: current,
            runtimeAgendaReminder: true,
            facadeItems: [current, next],
            facadeCurrent: current,
            facadeAgendaReminder: false
        )

        XCTAssertNil(viewModel.agendaReminderPrompt(now: Date(timeIntervalSince1970: 120)))
    }

    func testAgendaReminderPromptUsesRuntimeQueueWhenProgramQueueOwned() throws {
        let current = scheduledProgram("Runtime Current", start: 0)
        let next = scheduledProgram("Runtime Next", start: 100)
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            runtimeItems: [current, next],
            runtimeCurrent: current,
            runtimeAgendaReminder: true,
            facadeItems: [],
            facadeCurrent: current,
            facadeAgendaReminder: true
        )

        let prompt = viewModel.agendaReminderPrompt(now: Date(timeIntervalSince1970: 120))

        XCTAssertEqual(prompt?.itemID, next.id)
    }

    func testAgendaReminderPromptUsesRuntimeCurrentProgramWhenProgramSelectionOwned() throws {
        let current = scheduledProgram("Runtime Current", start: 0)
        let next = scheduledProgram("Runtime Next", start: 100)
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            runtimeItems: [current, next],
            runtimeCurrent: current,
            runtimeAgendaReminder: true,
            facadeItems: [current, next],
            facadeCurrent: nil,
            facadeAgendaReminder: true
        )

        let prompt = viewModel.agendaReminderPrompt(now: Date(timeIntervalSince1970: 120))

        XCTAssertEqual(prompt?.itemID, next.id)
    }

    func testAgendaReminderPromptDoesNotUseStaleFacadeQueueWhenProgramQueueOwned() {
        let runtimeCurrent = scheduledProgram("Runtime Current", start: 0)
        let runtimeNext = scheduledProgram("Runtime Next", start: 200)
        let staleFacadeNext = scheduledProgram("Facade Next", start: 100)
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            runtimeItems: [runtimeCurrent, runtimeNext],
            runtimeCurrent: runtimeCurrent,
            runtimeAgendaReminder: true,
            facadeItems: [runtimeCurrent, staleFacadeNext],
            facadeCurrent: runtimeCurrent,
            facadeAgendaReminder: true
        )

        let prompt = viewModel.agendaReminderPrompt(now: Date(timeIntervalSince1970: 120))

        XCTAssertNil(prompt)
    }

    func testAgendaReminderPromptDoesNotUseStaleFacadeCurrentProgramWhenProgramSelectionOwned() {
        let runtimeCurrent = scheduledProgram("Runtime Current", start: 0)
        let runtimeNext = scheduledProgram("Runtime Next", start: 100)
        let staleFacadeCurrent = scheduledProgram("Facade Current", start: 0)
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            runtimeItems: [runtimeCurrent, runtimeNext],
            runtimeCurrent: runtimeCurrent,
            runtimeAgendaReminder: true,
            facadeItems: [staleFacadeCurrent, runtimeCurrent, runtimeNext],
            facadeCurrent: staleFacadeCurrent,
            facadeAgendaReminder: true
        )

        let prompt = viewModel.agendaReminderPrompt(now: Date(timeIntervalSince1970: 120))

        XCTAssertEqual(prompt?.itemID, runtimeNext.id)
    }

    func testAgendaReminderPromptStillSuppressesPromptedIDs() {
        let current = scheduledProgram("Current", start: 0)
        let next = scheduledProgram("Next", start: 100)
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            runtimeItems: [current, next],
            runtimeCurrent: current,
            runtimeAgendaReminder: true,
            facadeItems: [current, next],
            facadeCurrent: current,
            facadeAgendaReminder: true
        )
        viewModel.agendaReminderAcknowledgedItemIDs.insert(next.id)

        XCTAssertNil(viewModel.agendaReminderPrompt(now: Date(timeIntervalSince1970: 120)))
    }

    func testAgendaReminderPromptStillReturnsNilWhenDisabled() {
        let current = scheduledProgram("Current", start: 0)
        let next = scheduledProgram("Next", start: 100)
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            runtimeItems: [current, next],
            runtimeCurrent: current,
            runtimeAgendaReminder: false,
            facadeItems: [current, next],
            facadeCurrent: current,
            facadeAgendaReminder: true
        )

        XCTAssertNil(viewModel.agendaReminderPrompt(now: Date(timeIntervalSince1970: 120)))
    }

    func testAgendaReminderPromptUsesRuntimeBackedSources() throws {
        let body = try XCTUnwrap(try programQueueSource().extractedRuntimeFunctionBody(named: "agendaReminderPrompt"))

        XCTAssertTrue(body.contains("runtimeBackedAgendaTimeReminderEnabledForProgramQueueViewModel"))
        XCTAssertTrue(body.contains("runtimeBackedProgramItemsForProgramQueueViewModel"))
        XCTAssertTrue(body.contains("runtimeBackedCurrentProgramForProgramQueueViewModel"))
        XCTAssertFalse(body.contains("isEnabled: isAgendaTimeReminderEnabled"))
        XCTAssertFalse(body.contains("programItems: programItems"))
        XCTAssertFalse(body.contains("currentProgramItem: currentProgramItem"))
    }

    private func programQueueSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramQueue.swift")
    }

    private func makeViewModel(
        bridgeMode: LiveRuntimeBridgeMode,
        runtimeItems: [ProgramItem],
        runtimeCurrent: ProgramItem?,
        runtimeAgendaReminder: Bool,
        facadeItems: [ProgramItem],
        facadeCurrent: ProgramItem?,
        facadeAgendaReminder: Bool
    ) -> SwitcherViewModel {
        var state = LiveRuntimeState()
        state.program.items = runtimeItems
        state.program.currentID = runtimeCurrent?.id
        state.program.currentSwitchedAt = runtimeCurrent == nil ? nil : Date(timeIntervalSince1970: 10)
        state.preferences.isAgendaTimeReminderEnabled = runtimeAgendaReminder
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        let suiteName = "AgendaReminderRuntimeSourceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults,
            runtime: runtime
        )
        viewModel.applyProgramQueueProjectionFromRuntime(facadeItems)
        viewModel.applyCurrentProgramProjectionFromRuntime(
            facadeCurrent,
            switchedAt: facadeCurrent == nil ? nil : Date(timeIntervalSince1970: 10)
        )
        viewModel.isAgendaTimeReminderEnabled = facadeAgendaReminder
        viewModel.runtime.replaceStateForFacadeSync(state, clearActionLog: true)
        return viewModel
    }

    private func scheduledProgram(_ title: String, start: TimeInterval) -> ProgramItem {
        ProgramItem(
            title: title,
            subtitle: "VIDEO",
            sourceURL: temporaryProgramFile(),
            scheduledStartAt: Date(timeIntervalSince1970: start),
            scheduledDuration: 60
        )
    }

    private func temporaryProgramFile() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        try? Data("fixture".utf8).write(to: url)
        return url
    }
}
