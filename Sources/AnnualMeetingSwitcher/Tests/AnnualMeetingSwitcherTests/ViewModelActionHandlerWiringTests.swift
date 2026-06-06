import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelActionHandlerWiringTests: XCTestCase {
    func testActionHandlersStructExists() {
        let handlers = SwitcherViewModelActionHandlers()

        handlers.keynotePresentation(URL(fileURLWithPath: "/tmp/deck.key"))
        handlers.pptxOpen(URL(fileURLWithPath: "/tmp/deck.pptx"))
        handlers.deckStop()
        handlers.programSeekToStart()
        handlers.programRestartFromBeginning {}
        handlers.programSeekToEnd()
        handlers.activeDeckPresentation()
        handlers.invalidDeck(URL(fileURLWithPath: "/tmp/invalid.key"))
    }

    func testActionHandlersHaveExpectedDefaultNoopBehavior() {
        let handlers = SwitcherViewModelActionHandlers()

        handlers.keynotePresentation(URL(fileURLWithPath: "/tmp/deck.key"))
        handlers.pptxOpen(URL(fileURLWithPath: "/tmp/deck.pptx"))
        handlers.deckStop()
        handlers.programSeekToStart()
        handlers.programRestartFromBeginning {}
        handlers.programSeekToEnd()
        handlers.activeDeckPresentation()
        handlers.invalidDeck(URL(fileURLWithPath: "/tmp/invalid.key"))
    }

    func testViewModelUsesGroupedActionHandlers() throws {
        let source = try viewModelSource()

        XCTAssertTrue(source.contains("@ObservationIgnored var actionHandlers = SwitcherViewModelActionHandlers()"))
    }

    func testViewModelInitDoesNotAssignLooseActionHandlerClosures() throws {
        let source = try viewModelSource()

        [
            "self.keynotePresentationHandler =",
            "self.pptxOpenHandler =",
            "self.deckStopHandler =",
            "self.programSeekToStartHandler =",
            "self.programRestartFromBeginningHandler =",
            "self.programSeekToEndHandler =",
            "self.activeDeckPresentationHandler =",
            "self.invalidDeckHandler ="
        ].forEach { snippet in
            XCTAssertFalse(source.contains(snippet), snippet)
        }
    }

    func testConfigureDefaultActionHandlersLivesInActionHandlerWiringExtension() throws {
        let source = try XCTUnwrap(
            optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ActionHandlerWiring.swift")
        )

        XCTAssertTrue(source.contains("func configureDefaultActionHandlers()"))
        XCTAssertTrue(source.contains("actionHandlers.keynotePresentation"))
        XCTAssertTrue(source.contains("actionHandlers.pptxOpen"))
        XCTAssertTrue(source.contains("actionHandlers.deckStop"))
    }

    func testKeynoteProgramSwitchStillUsesKeynotePresentationHandler() {
        let viewModel = makeViewModel()
        let item = deckProgram(extension: "key")
        var openedURL: URL?
        viewModel.actionHandlers.keynotePresentation = { openedURL = $0 }
        viewModel.actionHandlers.deckStop = {}
        viewModel.addProgramItem(item)

        viewModel.switchToProgram(item)

        XCTAssertEqual(openedURL, item.sourceURL)
    }

    func testPPTXProgramSwitchStillUsesPPTXOpenHandler() {
        let viewModel = makeViewModel()
        let item = deckProgram(extension: "pptx")
        var openedURL: URL?
        viewModel.actionHandlers.pptxOpen = { openedURL = $0 }
        viewModel.actionHandlers.deckStop = {}
        viewModel.addProgramItem(item)

        viewModel.switchToProgram(item)

        XCTAssertEqual(openedURL, item.sourceURL)
    }

    func testDeckStopStillUsesGroupedDeckStopHandler() {
        let viewModel = makeViewModel()
        let first = deckProgram(extension: "key")
        let second = deckProgram(extension: "pptx")
        var stopCount = 0
        viewModel.actionHandlers.keynotePresentation = { _ in }
        viewModel.actionHandlers.pptxOpen = { _ in }
        viewModel.actionHandlers.deckStop = { stopCount += 1 }
        viewModel.addProgramItems([first, second])

        viewModel.switchToProgram(first)
        viewModel.switchToProgram(second)

        XCTAssertEqual(stopCount, 1)
    }

    func testMediaSeekHandlersStillCallAVCoordinator() throws {
        let source = try XCTUnwrap(
            optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ActionHandlerWiring.swift")
        )

        XCTAssertTrue(source.contains("actionHandlers.programSeekToStart"))
        XCTAssertTrue(source.contains("avCoordinator.seekToBeginning()"))
        XCTAssertTrue(source.contains("actionHandlers.programRestartFromBeginning"))
        XCTAssertTrue(source.contains("avCoordinator.restartFromBeginning(onReadyToPlay: onReadyToPlay)"))
        XCTAssertTrue(source.contains("actionHandlers.programSeekToEnd"))
        XCTAssertTrue(source.contains("avCoordinator.seekToEnd()"))
    }

    func testInvalidDeckStillUsesGroupedInvalidDeckHandler() throws {
        let source = try XCTUnwrap(
            optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramQueue.swift")
        )

        XCTAssertTrue(source.contains("actionHandlers.invalidDeck(url)"))
        XCTAssertFalse(source.contains("invalidDeckHandler(url)"))
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "ViewModelActionHandlerWiringTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
    }

    private func deckProgram(extension pathExtension: String) -> ProgramItem {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(pathExtension)
        try? Data("fixture".utf8).write(to: url)
        return ProgramItem(
            title: "Deck",
            subtitle: pathExtension.uppercased(),
            sourceURL: url
        )
    }

    private func viewModelSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
    }
}
