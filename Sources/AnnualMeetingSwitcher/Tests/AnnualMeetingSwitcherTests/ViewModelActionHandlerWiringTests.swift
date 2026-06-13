import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelActionHandlerWiringTests: XCTestCase {
    func testProgramActivationSideEffectHandlersHaveExpectedDefaultNoopBehavior() {
        let handlers = ProgramActivationSideEffectHandlers()

        handlers.presentKeynote(URL(fileURLWithPath: "/tmp/deck.key"))
        handlers.openPPTX(URL(fileURLWithPath: "/tmp/deck.pptx"))
        handlers.stopDeck()
        handlers.presentActiveDeck()
        handlers.presentInvalidDeckAlert(URL(fileURLWithPath: "/tmp/invalid.key"))
    }

    func testViewModelUsesGroupedProgramActivationSideEffects() throws {
        let source = try viewModelSource()

        XCTAssertTrue(source.contains("@ObservationIgnored var programActivationSideEffects = ProgramActivationSideEffectHandlers()"))
        XCTAssertFalse(source.contains("@ObservationIgnored var actionHandlers"))
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

    func testConfigureDefaultProgramActivationSideEffectsLivesInDedicatedExtension() throws {
        let source = try XCTUnwrap(
            optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivationSideEffectWiring.swift")
        )

        XCTAssertTrue(source.contains("func configureDefaultProgramActivationSideEffects()"))
        XCTAssertTrue(source.contains("programActivationSideEffects.presentKeynote"))
        XCTAssertTrue(source.contains("programActivationSideEffects.openPPTX"))
        XCTAssertTrue(source.contains("programActivationSideEffects.stopDeck"))
        XCTAssertTrue(source.contains("programActivationSideEffects.presentActiveDeck"))
        XCTAssertTrue(source.contains("programActivationSideEffects.presentInvalidDeckAlert"))
    }

    func testKeynoteProgramSwitchStillUsesPresentKeynoteSideEffect() {
        let viewModel = makeViewModel()
        let item = deckProgram(extension: "key")
        var openedURL: URL?
        viewModel.programActivationSideEffects.presentKeynote = { openedURL = $0 }
        viewModel.programActivationSideEffects.stopDeck = {}
        viewModel.addProgramItem(item)

        viewModel.switchToProgram(item)

        XCTAssertEqual(openedURL, item.sourceURL)
    }

    func testPPTXProgramSwitchStillUsesOpenPPTXSideEffect() {
        let viewModel = makeViewModel()
        let item = deckProgram(extension: "pptx")
        var openedURL: URL?
        viewModel.programActivationSideEffects.openPPTX = { openedURL = $0 }
        viewModel.programActivationSideEffects.stopDeck = {}
        viewModel.addProgramItem(item)

        viewModel.switchToProgram(item)

        XCTAssertEqual(openedURL, item.sourceURL)
    }

    func testDeckStopStillUsesActivationSideEffect() {
        let viewModel = makeViewModel()
        let first = deckProgram(extension: "key")
        let second = deckProgram(extension: "pptx")
        var stopCount = 0
        viewModel.programActivationSideEffects.presentKeynote = { _ in }
        viewModel.programActivationSideEffects.openPPTX = { _ in }
        viewModel.programActivationSideEffects.stopDeck = { stopCount += 1 }
        viewModel.addProgramItems([first, second])

        viewModel.switchToProgram(first)
        viewModel.switchToProgram(second)

        XCTAssertEqual(stopCount, 1)
    }

    func testDefaultWiringDoesNotWireMediaSeekHandlers() throws {
        let source = try XCTUnwrap(
            optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivationSideEffectWiring.swift")
        )

        XCTAssertFalse(source.contains("programSeekToStart"))
        XCTAssertFalse(source.contains("programRestartFromBeginning"))
        XCTAssertFalse(source.contains("programSeekToEnd"))
        XCTAssertFalse(source.contains("avCoordinator.seekToBeginning"))
        XCTAssertFalse(source.contains("avCoordinator.restartFromBeginning"))
        XCTAssertFalse(source.contains("avCoordinator.seekToEnd"))
    }

    func testInvalidDeckStillUsesActivationSideEffect() throws {
        let source = try XCTUnwrap(
            optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivationRuntimeBridge.swift")
        )

        XCTAssertTrue(source.contains("programActivationSideEffects.presentInvalidDeckAlert(url)"))
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
