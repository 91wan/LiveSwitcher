import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramQueueViewModelSourceBoundaryTests: XCTestCase {
    func testProgramQueueViewModelUsesRuntimeQueueWhenProgramQueueOwned() throws {
        let runtimeItem = mediaProgram("Runtime")
        let viewModel = makeViewModel(bridgeMode: .programQueueOwned, runtimeItems: [runtimeItem], facadeItems: [])

        viewModel.removeProgramItem(withID: runtimeItem.id)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorRemovedProgramItem" })
    }

    func testProgramQueueViewModelUsesFacadeQueueBeforeProgramQueueOwnership() throws {
        let source = try programQueueSource()

        XCTAssertTrue(source.contains(": programItems"))
    }

    func testProgramQueueViewModelUsesRuntimeCurrentProgramWhenProgramSelectionOwned() throws {
        let runtimeCurrent = mediaProgram("Runtime Current")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            runtimeItems: [runtimeCurrent],
            runtimeCurrent: runtimeCurrent,
            facadeItems: [runtimeCurrent],
            facadeCurrent: nil
        )

        viewModel.removeProgramItem(withID: runtimeCurrent.id)

        XCTAssertEqual(actionCount("operatorStoppedCurrentMedia", in: viewModel), 1)
    }

    func testProgramQueueViewModelUsesFacadeCurrentProgramBeforeProgramSelectionOwnership() throws {
        let source = try programQueueSource()

        XCTAssertTrue(source.contains(": currentProgramItem"))
    }

    func testProgramQueueViewModelUsesRuntimeAgendaReminderPreferenceWhenPersistenceOwned() throws {
        let source = try programQueueSource()

        XCTAssertTrue(source.contains("? runtime.state.preferences.isAgendaTimeReminderEnabled"))
    }

    func testProgramQueueViewModelSourceHelpersExist() throws {
        let source = try programQueueSource()

        XCTAssertTrue(source.contains("runtimeBackedProgramItemsForProgramQueueViewModel"))
        XCTAssertTrue(source.contains("runtimeBackedCurrentProgramForProgramQueueViewModel"))
        XCTAssertTrue(source.contains("runtimeBackedAgendaTimeReminderEnabledForProgramQueueViewModel"))
        XCTAssertTrue(source.contains("runtimeBackedProgramItemForProgramQueueViewModel"))
    }

    func testRemoveProgramItemUsesRuntimeRemovedItemWhenProgramQueueOwned() {
        let id = UUID()
        let runtimeMedia = mediaProgram("Runtime Media", id: id)
        let staleFacadeDeck = activeDeck("Facade Deck", id: id)
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            runtimeItems: [runtimeMedia],
            runtimeCurrent: runtimeMedia,
            facadeItems: [staleFacadeDeck],
            facadeCurrent: runtimeMedia
        )
        var stopDeckCount = 0
        viewModel.programActivationSideEffects.stopDeck = { stopDeckCount += 1 }

        viewModel.removeProgramItem(withID: id)

        XCTAssertEqual(actionCount("operatorStoppedCurrentMedia", in: viewModel), 1)
        XCTAssertEqual(stopDeckCount, 0)
    }

    func testRemoveProgramItemUsesFacadeRemovedItemBeforeProgramQueueOwnership() {
        let id = UUID()
        let runtimeMedia = mediaProgram("Runtime Media", id: id)
        let facadeDeck = activeDeck("Facade Deck", id: id)
        let viewModel = makeViewModel(
            bridgeMode: .recordingOnly,
            runtimeItems: [runtimeMedia],
            runtimeCurrent: runtimeMedia,
            facadeItems: [facadeDeck],
            facadeCurrent: facadeDeck
        )
        var stopDeckCount = 0
        viewModel.programActivationSideEffects.stopDeck = { stopDeckCount += 1 }

        viewModel.removeProgramItem(withID: id)

        XCTAssertEqual(stopDeckCount, 1)
        XCTAssertEqual(actionCount("operatorStoppedCurrentMedia", in: viewModel), 0)
    }

    func testRemoveProgramItemUsesRuntimeCurrentProgramWhenProgramSelectionOwned() {
        let current = activeDeck("Runtime Deck")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            runtimeItems: [current],
            runtimeCurrent: current,
            facadeItems: [current],
            facadeCurrent: nil
        )
        var stopDeckCount = 0
        viewModel.programActivationSideEffects.stopDeck = { stopDeckCount += 1 }

        viewModel.removeProgramItem(withID: current.id)

        XCTAssertEqual(stopDeckCount, 1)
    }

    func testRemoveCurrentRuntimeMediaDispatchesStopMediaEvenIfFacadeCurrentIsStale() {
        let current = mediaProgram("Runtime Media")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            runtimeItems: [current],
            runtimeCurrent: current,
            facadeItems: [current],
            facadeCurrent: nil
        )

        viewModel.removeProgramItem(withID: current.id)

        XCTAssertEqual(actionCount("operatorStoppedCurrentMedia", in: viewModel), 1)
    }

    func testRemoveCurrentRuntimeDeckStopsDeckEvenIfFacadeCurrentIsStale() {
        let current = activeDeck("Runtime Deck")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            runtimeItems: [current],
            runtimeCurrent: current,
            facadeItems: [current],
            facadeCurrent: nil
        )
        var stopDeckCount = 0
        viewModel.programActivationSideEffects.stopDeck = { stopDeckCount += 1 }

        viewModel.removeProgramItem(withID: current.id)

        XCTAssertEqual(stopDeckCount, 1)
    }

    func testRemoveNonCurrentRuntimeItemDoesNotStopDeckEvenIfFacadeCurrentMatches() {
        let removed = activeDeck("Removed")
        let runtimeCurrent = mediaProgram("Runtime Current")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            runtimeItems: [removed, runtimeCurrent],
            runtimeCurrent: runtimeCurrent,
            facadeItems: [removed, runtimeCurrent],
            facadeCurrent: removed
        )
        var stopDeckCount = 0
        viewModel.programActivationSideEffects.stopDeck = { stopDeckCount += 1 }

        viewModel.removeProgramItem(withID: removed.id)

        XCTAssertEqual(stopDeckCount, 0)
    }

    func testRemoveCurrentRuntimeHTMLClearsHTMLURL() {
        let current = htmlProgram("Runtime HTML")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            runtimeItems: [current],
            runtimeCurrent: current,
            facadeItems: [current],
            facadeCurrent: nil
        )
        viewModel.currentHTMLURL = current.sourceURL

        viewModel.removeProgramItem(withID: current.id)

        XCTAssertNil(viewModel.currentHTMLURL)
    }

    func testRemoveCurrentProgramDoesNotCallLegacyClearWhenProgramSelectionOwned() {
        let current = mediaProgram("Runtime Media")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            runtimeItems: [current],
            runtimeCurrent: current,
            facadeItems: [current],
            facadeCurrent: nil
        )

        viewModel.removeProgramItem(withID: current.id)

        XCTAssertEqual(actionCount("operatorClearedCurrentProgram", in: viewModel), 0)
    }

    func testRemoveCurrentProgramCallsLegacyClearBeforeProgramSelectionOwnership() {
        let current = mediaProgram("Facade Media")
        let viewModel = makeViewModel(
            bridgeMode: .recordingOnly,
            runtimeItems: [current],
            runtimeCurrent: current,
            facadeItems: [current],
            facadeCurrent: current
        )

        viewModel.removeProgramItem(withID: current.id)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertEqual(actionCount("operatorClearedCurrentProgram", in: viewModel), 0)
    }

    func testRemoveProgramItemDoesNotReadFacadeCurrentProgramDirectly() throws {
        let body = try XCTUnwrap(try programQueueSource().extractedRuntimeFunctionBody(named: "removeProgramItem"))

        XCTAssertFalse(body.contains("programItems.first { $0.id == id }"))
        XCTAssertFalse(body.contains("currentProgramItem?.id == id"))
    }

    func testAddProgramItemsStillSavesAfterRuntimeDispatch() {
        let viewModel = makeViewModel(bridgeMode: .programQueueOwned, runtimeItems: [], facadeItems: [])
        var saveCount = 0
        viewModel.testHooks.saveDataDidRun = { saveCount += 1 }

        viewModel.addProgramItems([mediaProgram("Added")])

        XCTAssertEqual(saveCount, 1)
        XCTAssertEqual(actionCount("operatorAddedProgramItems", in: viewModel), 1)
    }

    func testRemoveProgramItemStillSavesAfterRuntimeDispatch() {
        let item = mediaProgram("Removed")
        let viewModel = makeViewModel(bridgeMode: .programQueueOwned, runtimeItems: [item], facadeItems: [item])
        var saveCount = 0
        viewModel.testHooks.saveDataDidRun = { saveCount += 1 }

        viewModel.removeProgramItem(withID: item.id)

        XCTAssertEqual(saveCount, 1)
        XCTAssertEqual(actionCount("operatorRemovedProgramItem", in: viewModel), 1)
    }

    func testMoveProgramItemsStillSavesAfterRuntimeDispatch() {
        let first = mediaProgram("First")
        let second = mediaProgram("Second")
        let viewModel = makeViewModel(bridgeMode: .programQueueOwned, runtimeItems: [first, second], facadeItems: [first, second])
        var saveCount = 0
        viewModel.testHooks.saveDataDidRun = { saveCount += 1 }

        viewModel.moveProgramItems(from: IndexSet(integer: 0), to: 2)

        XCTAssertEqual(saveCount, 1)
        XCTAssertEqual(actionCount("operatorMovedProgramItems", in: viewModel), 1)
    }

    func testUpdateProgramItemScheduleStillSavesAfterRuntimeDispatch() {
        let item = mediaProgram("Scheduled")
        let viewModel = makeViewModel(bridgeMode: .programQueueOwned, runtimeItems: [item], facadeItems: [item])
        var saveCount = 0
        viewModel.testHooks.saveDataDidRun = { saveCount += 1 }

        viewModel.updateProgramItemSchedule(
            id: item.id,
            scheduledStartAt: Date(timeIntervalSince1970: 100),
            scheduledDuration: 60
        )

        XCTAssertEqual(saveCount, 1)
        XCTAssertEqual(actionCount("operatorUpdatedProgramItemSchedule", in: viewModel), 1)
    }

    func testAddAgendaMarkerStillSavesAfterRuntimeDispatch() {
        let viewModel = makeViewModel(bridgeMode: .programQueueOwned, runtimeItems: [], facadeItems: [])
        var saveCount = 0
        viewModel.testHooks.saveDataDidRun = { saveCount += 1 }

        let input = AgendaMarkerInput(title: "茶歇", scheduledStartAt: nil, duration: 15 * 60)
        viewModel.addAgendaMarker(input)

        XCTAssertEqual(saveCount, 1)
        XCTAssertEqual(actionCount("operatorAddedAgendaMarker", in: viewModel), 1)
    }

    func testUpdateAgendaMarkerStillSavesAfterSingleRuntimeDispatch() {
        let marker = ProgramItem.agendaMarker(title: "茶歇")
        let viewModel = makeViewModel(bridgeMode: .programQueueOwned, runtimeItems: [marker], facadeItems: [marker])
        var saveCount = 0
        viewModel.testHooks.saveDataDidRun = { saveCount += 1 }

        viewModel.updateAgendaMarker(
            id: marker.id,
            input: AgendaMarkerInput(title: "转场", scheduledStartAt: Date(timeIntervalSince1970: 100), duration: 20 * 60)
        )

        XCTAssertEqual(saveCount, 1)
        XCTAssertEqual(actionCount("operatorUpdatedAgendaMarker", in: viewModel), 1)
        XCTAssertEqual(actionCount("operatorUpdatedProgramItemSchedule", in: viewModel), 0)
    }

    func testProgramQueueActionsStillSyncProgramQueueFacadeThroughPolicy() {
        let first = mediaProgram("First")
        let second = mediaProgram("Second")
        let viewModel = makeViewModel(bridgeMode: .programQueueOwned, runtimeItems: [first, second], facadeItems: [])

        viewModel.moveProgramItems(from: IndexSet(integer: 0), to: 2)

        XCTAssertEqual(viewModel.programItems.map(\.id), [second.id, first.id])
    }

    func testRemoveProgramItemStillSyncsCurrentProgramFacadeThroughPolicy() {
        let current = mediaProgram("Current")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            runtimeItems: [current],
            runtimeCurrent: current,
            facadeItems: [current],
            facadeCurrent: current
        )

        viewModel.removeProgramItem(withID: current.id)

        XCTAssertNil(viewModel.currentProgramItem)
    }

    func testNoProgramQueueViewModelBridgeModeDomainOrPortAdded() throws {
        let runtimeSource = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeState.swift")
        let portsSource = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeEffectPortKind.swift")

        XCTAssertFalse(runtimeSource.contains("programQueueViewModelOwned"))
        XCTAssertFalse(runtimeSource.contains("agendaPromptOwned"))
        XCTAssertFalse(runtimeSource.contains("removeProgramSideEffectsOwned"))
        XCTAssertFalse(portsSource.contains("programQueueViewModel"))
        XCTAssertFalse(portsSource.contains("agendaPrompt"))
        XCTAssertFalse(portsSource.contains("removeProgramSideEffects"))
    }

    private func programQueueSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramQueue.swift")
    }

    private func makeViewModel(
        bridgeMode: LiveRuntimeBridgeMode,
        runtimeItems: [ProgramItem],
        runtimeCurrent: ProgramItem? = nil,
        runtimeAgendaReminder: Bool = false,
        facadeItems: [ProgramItem],
        facadeCurrent: ProgramItem? = nil,
        facadeAgendaReminder: Bool = false
    ) -> SwitcherViewModel {
        var state = LiveRuntimeState()
        state.program.items = runtimeItems
        state.program.currentID = runtimeCurrent?.id
        state.program.currentSwitchedAt = runtimeCurrent == nil ? nil : Date(timeIntervalSince1970: 100)
        state.preferences.isAgendaTimeReminderEnabled = runtimeAgendaReminder
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        let suiteName = "ProgramQueueViewModelSourceBoundaryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults,
            runtime: runtime
        )
        viewModel.programActivationSideEffects.stopDeck = {}
        viewModel.applyProgramQueueProjectionFromRuntime(facadeItems)
        viewModel.applyCurrentProgramProjectionFromRuntime(
            facadeCurrent,
            switchedAt: facadeCurrent == nil ? nil : Date(timeIntervalSince1970: 10)
        )
        viewModel.isAgendaTimeReminderEnabled = facadeAgendaReminder
        viewModel.runtime.replaceStateForFacadeSync(state, clearActionLog: true)
        return viewModel
    }

    private func actionCount(_ name: String, in viewModel: SwitcherViewModel) -> Int {
        viewModel.runtime.actionLog.filter { $0.actionName == name }.count
    }

    private func mediaProgram(_ title: String, id: UUID = UUID()) -> ProgramItem {
        ProgramItem(
            id: id,
            title: title,
            subtitle: "VIDEO",
            sourceURL: temporaryProgramFile(ext: "mp4")
        )
    }

    private func htmlProgram(_ title: String, id: UUID = UUID()) -> ProgramItem {
        ProgramItem(
            id: id,
            title: title,
            subtitle: "HTML",
            sourceURL: temporaryProgramFile(ext: "html")
        )
    }

    private func activeDeck(_ title: String, id: UUID = UUID()) -> ProgramItem {
        ProgramItem(id: id, title: title, subtitle: "KEY (active)", sourceURL: nil)
    }

    private func temporaryProgramFile(ext: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try? Data("fixture".utf8).write(to: url)
        return url
    }
}
