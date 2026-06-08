import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelProgramQueueExtractionTests: XCTestCase {
    func testProgramQueueMethodsAreNotDeclaredInMainViewModel() throws {
        let source = try viewModelSource()
        let forbiddenSnippets = [
            "func switchToProgram(",
            "func addProgramItem(",
            "func removeProgramItem(",
            "func agendaAutoAdvancePrompt(",
            "func toggleMainVideoPlayback(",
            "func restartCurrentMediaFromBeginning("
        ]

        for snippet in forbiddenSnippets {
            XCTAssertFalse(source.contains(snippet), snippet)
        }
    }

    func testProgramQueueMethodsLiveInProgramQueueExtension() throws {
        let source = try XCTUnwrap(programQueueExtensionSource())

        XCTAssertTrue(source.contains("extension SwitcherViewModel"))
        for snippet in [
            "func addProgramItem(",
            "func addProgramItems(",
            "func removeProgramItem(",
            "func moveProgramItems(",
            "func agendaAutoAdvancePrompt("
        ] {
            XCTAssertTrue(source.contains(snippet), snippet)
        }
    }

    func testSwitchToProgramStillDispatchesRuntimeProgramSelection() {
        let viewModel = makeViewModel()
        let item = mediaProgram()
        viewModel.addProgramItem(item)
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)

        viewModel.switchToProgram(item)

        XCTAssertEqual(actionCount("operatorSelectedProgram", in: viewModel), 1)
    }

    func testSwitchToProgramStillSuppressesDuplicateFacadeCurrentProgramChanged() {
        let viewModel = makeViewModel()
        let item = mediaProgram()
        viewModel.addProgramItem(item)
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)

        viewModel.switchToProgram(item)

        XCTAssertEqual(actionCount("operatorSelectedProgram", in: viewModel), 1)
        XCTAssertEqual(actionCount("facadeCurrentProgramChanged", in: viewModel), 0)
    }

    func testSwitchToMissingProgramSourceStillRecordsSupportEvent() {
        let viewModel = makeViewModel()
        let item = ProgramItem(
            title: "Missing",
            subtitle: "VIDEO",
            sourceURL: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")
        )

        viewModel.switchToProgram(item)

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .programItemFileMissing })
        XCTAssertEqual(viewModel.automationRuntimeNotice?.action, "program.source.missing")
    }

    func testRemoveCurrentMediaProgramStillStopsMediaThroughRuntime() {
        let viewModel = makeViewModel()
        let item = mediaProgram()
        viewModel.addProgramItem(item)
        viewModel.switchToProgram(item)
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)

        viewModel.removeProgramItem(withID: item.id)

        XCTAssertEqual(actionCount("operatorStoppedCurrentMedia", in: viewModel), 1)
        XCTAssertNil(viewModel.currentProgramItem)
    }

    func testAgendaAutoAdvanceStillUsesProgramQueueStore() throws {
        let body = try XCTUnwrap(programQueueExtensionSource()?.extractedRuntimeFunctionBody(named: "agendaAutoAdvancePrompt"))

        XCTAssertTrue(body.contains("AgendaAutoAdvanceModel.prompt("))
        XCTAssertTrue(body.contains("programItems: programItems"))
    }

    func testProgramQueueStorageIsRuntimeOwnedAndProjectedToViewModel() {
        let viewModel = makeViewModel()
        let item = mediaProgram()

        viewModel.addProgramItem(item)

        XCTAssertEqual(viewModel.programItems.map(\.id), [item.id])
        XCTAssertEqual(viewModel.runtime.state.program.items.map(\.id), [item.id])
    }

    private func viewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }

    private func programQueueExtensionSource() throws -> String? {
        try optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramQueue.swift")
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "ViewModelProgramQueueExtractionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
        viewModel.programActivationSideEffects.presentKeynote = { _ in }
        viewModel.programActivationSideEffects.openPPTX = { _ in }
        viewModel.programActivationSideEffects.presentActiveDeck = {}
        viewModel.programActivationSideEffects.stopDeck = {}
        return viewModel
    }

    private func actionCount(_ name: String, in viewModel: SwitcherViewModel) -> Int {
        viewModel.runtime.actionLog.filter { $0.actionName == name }.count
    }

    private func mediaProgram() -> ProgramItem {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        try? Data("fixture".utf8).write(to: url)
        return ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: url)
    }
}
