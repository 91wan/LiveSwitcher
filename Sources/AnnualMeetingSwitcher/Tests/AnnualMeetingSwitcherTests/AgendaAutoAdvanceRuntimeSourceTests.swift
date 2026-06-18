import XCTest
@testable import LiveSwitcher

@MainActor
final class AgendaAutoAdvanceRuntimeSourceTests: XCTestCase {
    func testAgendaAutoAdvancePromptUsesRuntimePreferenceWhenPersistenceOwned() throws {
        let current = scheduledProgram("Current", start: 0)
        let next = scheduledProgram("Next", start: 100)
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            runtimeItems: [current, next],
            runtimeCurrent: current,
            runtimeAutoAdvance: true,
            facadeItems: [current, next],
            facadeCurrent: current,
            facadeAutoAdvance: false
        )

        let prompt = viewModel.agendaAutoAdvancePrompt(now: Date(timeIntervalSince1970: 120))

        XCTAssertEqual(prompt?.itemID, next.id)
    }

    func testAgendaAutoAdvancePromptUsesFacadePreferenceBeforePersistenceOwnership() {
        let current = scheduledProgram("Current", start: 0)
        let next = scheduledProgram("Next", start: 100)
        let viewModel = makeViewModel(
            bridgeMode: .recordingOnly,
            runtimeItems: [current, next],
            runtimeCurrent: current,
            runtimeAutoAdvance: true,
            facadeItems: [current, next],
            facadeCurrent: current,
            facadeAutoAdvance: false
        )

        XCTAssertNil(viewModel.agendaAutoAdvancePrompt(now: Date(timeIntervalSince1970: 120)))
    }

    func testAgendaAutoAdvancePromptUsesRuntimeQueueWhenProgramQueueOwned() throws {
        let current = scheduledProgram("Runtime Current", start: 0)
        let next = scheduledProgram("Runtime Next", start: 100)
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            runtimeItems: [current, next],
            runtimeCurrent: current,
            runtimeAutoAdvance: true,
            facadeItems: [],
            facadeCurrent: current,
            facadeAutoAdvance: true
        )

        let prompt = viewModel.agendaAutoAdvancePrompt(now: Date(timeIntervalSince1970: 120))

        XCTAssertEqual(prompt?.itemID, next.id)
    }

    func testAgendaAutoAdvancePromptUsesRuntimeCurrentProgramWhenProgramSelectionOwned() throws {
        let current = scheduledProgram("Runtime Current", start: 0)
        let next = scheduledProgram("Runtime Next", start: 100)
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            runtimeItems: [current, next],
            runtimeCurrent: current,
            runtimeAutoAdvance: true,
            facadeItems: [current, next],
            facadeCurrent: nil,
            facadeAutoAdvance: true
        )

        let prompt = viewModel.agendaAutoAdvancePrompt(now: Date(timeIntervalSince1970: 120))

        XCTAssertEqual(prompt?.itemID, next.id)
    }

    func testAgendaAutoAdvancePromptDoesNotUseStaleFacadeQueueWhenProgramQueueOwned() {
        let runtimeCurrent = scheduledProgram("Runtime Current", start: 0)
        let runtimeNext = scheduledProgram("Runtime Next", start: 200)
        let staleFacadeNext = scheduledProgram("Facade Next", start: 100)
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            runtimeItems: [runtimeCurrent, runtimeNext],
            runtimeCurrent: runtimeCurrent,
            runtimeAutoAdvance: true,
            facadeItems: [runtimeCurrent, staleFacadeNext],
            facadeCurrent: runtimeCurrent,
            facadeAutoAdvance: true
        )

        let prompt = viewModel.agendaAutoAdvancePrompt(now: Date(timeIntervalSince1970: 120))

        XCTAssertNil(prompt)
    }

    func testAgendaAutoAdvancePromptDoesNotUseStaleFacadeCurrentProgramWhenProgramSelectionOwned() {
        let runtimeCurrent = scheduledProgram("Runtime Current", start: 0)
        let runtimeNext = scheduledProgram("Runtime Next", start: 100)
        let staleFacadeCurrent = scheduledProgram("Facade Current", start: 0)
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            runtimeItems: [runtimeCurrent, runtimeNext],
            runtimeCurrent: runtimeCurrent,
            runtimeAutoAdvance: true,
            facadeItems: [staleFacadeCurrent, runtimeCurrent, runtimeNext],
            facadeCurrent: staleFacadeCurrent,
            facadeAutoAdvance: true
        )

        let prompt = viewModel.agendaAutoAdvancePrompt(now: Date(timeIntervalSince1970: 120))

        XCTAssertEqual(prompt?.itemID, runtimeNext.id)
    }

    func testAgendaAutoAdvancePromptStillSuppressesPromptedIDs() {
        let current = scheduledProgram("Current", start: 0)
        let next = scheduledProgram("Next", start: 100)
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            runtimeItems: [current, next],
            runtimeCurrent: current,
            runtimeAutoAdvance: true,
            facadeItems: [current, next],
            facadeCurrent: current,
            facadeAutoAdvance: true
        )
        viewModel.agendaAutoAdvancePromptedItemIDs.insert(next.id)

        XCTAssertNil(viewModel.agendaAutoAdvancePrompt(now: Date(timeIntervalSince1970: 120)))
    }

    func testAgendaAutoAdvancePromptStillReturnsNilWhenDisabled() {
        let current = scheduledProgram("Current", start: 0)
        let next = scheduledProgram("Next", start: 100)
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            runtimeItems: [current, next],
            runtimeCurrent: current,
            runtimeAutoAdvance: false,
            facadeItems: [current, next],
            facadeCurrent: current,
            facadeAutoAdvance: true
        )

        XCTAssertNil(viewModel.agendaAutoAdvancePrompt(now: Date(timeIntervalSince1970: 120)))
    }

    func testAgendaAutoAdvancePromptUsesRuntimeBackedSources() throws {
        let body = try XCTUnwrap(try programQueueSource().extractedRuntimeFunctionBody(named: "agendaAutoAdvancePrompt"))

        XCTAssertTrue(body.contains("runtimeBackedAutoAdvanceAtScheduledTimeForProgramQueueViewModel"))
        XCTAssertTrue(body.contains("runtimeBackedProgramItemsForProgramQueueViewModel"))
        XCTAssertTrue(body.contains("runtimeBackedCurrentProgramForProgramQueueViewModel"))
        XCTAssertFalse(body.contains("isEnabled: autoAdvanceAtScheduledTime"))
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
        runtimeAutoAdvance: Bool,
        facadeItems: [ProgramItem],
        facadeCurrent: ProgramItem?,
        facadeAutoAdvance: Bool
    ) -> SwitcherViewModel {
        var state = LiveRuntimeState()
        state.program.items = runtimeItems
        state.program.currentID = runtimeCurrent?.id
        state.program.currentSwitchedAt = runtimeCurrent == nil ? nil : Date(timeIntervalSince1970: 10)
        state.preferences.autoAdvanceAtScheduledTime = runtimeAutoAdvance
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        let suiteName = "AgendaAutoAdvanceRuntimeSourceTests.\(UUID().uuidString)"
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
        viewModel.autoAdvanceAtScheduledTime = facadeAutoAdvance
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
