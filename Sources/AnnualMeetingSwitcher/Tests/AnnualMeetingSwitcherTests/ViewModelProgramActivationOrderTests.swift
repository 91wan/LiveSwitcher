import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelProgramActivationOrderTests: XCTestCase {
    func testInvalidDeckReturnsBeforeDeckStop() throws {
        let current = activeDeckProgram()
        let invalid = try keynoteProgram(contents: Data())
        let viewModel = makeViewModel(initialItems: [current, invalid])
        setCurrentProgram(current, in: viewModel)
        var events: [String] = []
        viewModel.actionHandlers.invalidDeck = { _ in events.append("invalidDeck") }
        viewModel.actionHandlers.deckStop = { events.append("deckStop") }

        viewModel.switchToProgram(invalid)

        XCTAssertEqual(events, ["invalidDeck"])
    }

    func testInvalidDeckReturnsBeforeRuntimeSelection() throws {
        let invalid = try keynoteProgram(contents: Data())
        let viewModel = makeViewModel(initialItems: [invalid])
        viewModel.actionHandlers.invalidDeck = { _ in }

        viewModel.switchToProgram(invalid)

        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedProgram" })
    }

    func testInvalidDeckReturnsBeforeCurrentProgramUpdate() throws {
        let current = activeDeckProgram()
        let invalid = try keynoteProgram(contents: Data())
        let viewModel = makeViewModel(initialItems: [current, invalid])
        setCurrentProgram(current, in: viewModel)
        viewModel.actionHandlers.invalidDeck = { _ in }

        viewModel.switchToProgram(invalid)

        XCTAssertEqual(viewModel.currentProgramItem?.id, current.id)
        XCTAssertNotEqual(viewModel.currentProgramItem?.id, invalid.id)
    }

    func testNormalActivationStopsDeckBeforeRuntimeSelection() throws {
        let current = activeDeckProgram()
        let next = try mediaProgram()
        let viewModel = makeViewModel(initialItems: [current, next])
        setCurrentProgram(current, in: viewModel)
        var events: [String] = []
        viewModel.actionHandlers.deckStop = {
            events.append("deckStop:\(viewModel.runtime.actionLog.isEmpty)")
        }

        viewModel.switchToProgram(next)

        XCTAssertEqual(events, ["deckStop:true"])
        XCTAssertEqual(viewModel.runtime.actionLog.first?.actionName, "operatorSelectedProgram")
    }

    func testNormalActivationDispatchesRuntimeSelectionBeforeCurrentProgramUpdate() throws {
        let current = activeDeckProgram()
        let next = try mediaProgram()
        let viewModel = makeViewModel(initialItems: [current, next])
        setCurrentProgram(current, in: viewModel)

        viewModel.switchToProgram(next)

        let firstEntry = try XCTUnwrap(viewModel.runtime.actionLog.first)
        XCTAssertEqual(firstEntry.actionName, "operatorSelectedProgram")
        XCTAssertTrue(firstEntry.oldStateSummary.contains(current.id.uuidString))
        XCTAssertFalse(firstEntry.oldStateSummary.contains(next.id.uuidString))
        XCTAssertEqual(viewModel.currentProgramItem?.id, next.id)
    }

    func testNormalActivationSetsCurrentProgramBeforeSideEffect() throws {
        let item = try keynoteProgram(contents: Data("fixture".utf8))
        let viewModel = makeViewModel(initialItems: [item])
        var event: String?
        viewModel.actionHandlers.keynotePresentation = { _ in
            event = "keynote:\(viewModel.currentProgramItem?.id == item.id)"
        }

        viewModel.switchToProgram(item)

        XCTAssertEqual(event, "keynote:true")
    }

    func testMediaActivationClearsHTMLBeforeCompleting() throws {
        let item = try mediaProgram()
        let viewModel = makeViewModel(initialItems: [item])
        viewModel.currentHTMLURL = try temporaryFile(ext: "html")

        viewModel.switchToProgram(item)

        XCTAssertNil(viewModel.currentHTMLURL)
    }

    func testHTMLActivationOpensHTMLAndLeavesCurrentHTMLURLSet() throws {
        let item = try htmlProgram()
        let viewModel = makeViewModel(initialItems: [item])

        viewModel.switchToProgram(item)

        XCTAssertEqual(viewModel.currentHTMLURL, item.sourceURL)
    }

    func testActiveDeckActivationClearsHTMLBeforeHandler() throws {
        let item = activeDeckProgram()
        let viewModel = makeViewModel(initialItems: [item])
        viewModel.currentHTMLURL = try temporaryFile(ext: "html")
        var htmlWasClearedInHandler = false
        viewModel.actionHandlers.activeDeckPresentation = {
            htmlWasClearedInHandler = viewModel.currentHTMLURL == nil
        }

        viewModel.switchToProgram(item)

        XCTAssertTrue(htmlWasClearedInHandler)
    }

    func testMediaActivationClearsMutedStartupFlag() throws {
        let item = try mediaProgram()
        let viewModel = makeViewModel(initialItems: [item])
        viewModel.needsMutedMediaStartupAfterClearedProgram = true

        viewModel.switchToProgram(item)

        XCTAssertFalse(viewModel.needsMutedMediaStartupAfterClearedProgram)
    }

    private func makeViewModel(initialItems: [ProgramItem]) -> SwitcherViewModel {
        var state = LiveRuntimeState()
        state.program.items = initialItems
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: .productionProgramSelectionOwning()
        )
        let suiteName = "ViewModelProgramActivationOrderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults,
            runtime: runtime
        )
        viewModel.syncProgramQueueFacadeFromRuntime()
        viewModel.actionHandlers.deckStop = {}
        viewModel.actionHandlers.keynotePresentation = { _ in }
        viewModel.actionHandlers.pptxOpen = { _ in }
        viewModel.actionHandlers.activeDeckPresentation = {}
        viewModel.actionHandlers.invalidDeck = { _ in }
        return viewModel
    }

    private func setCurrentProgram(_ item: ProgramItem, in viewModel: SwitcherViewModel) {
        var state = viewModel.runtime.state
        state.program.items = viewModel.programItems
        state.program.currentID = item.id
        state.program.currentDetachedItem = state.program.items.contains { $0.id == item.id } ? nil : item
        state.program.currentSwitchedAt = Date()
        viewModel.runtime.replaceStateForFacadeSync(state, clearActionLog: true)
        viewModel.syncCurrentProgramFacadeFromRuntime()
    }

    private func mediaProgram() throws -> ProgramItem {
        ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: try temporaryFile(ext: "mp4"))
    }

    private func htmlProgram() throws -> ProgramItem {
        ProgramItem(title: "HTML", subtitle: "HTML", sourceURL: try temporaryFile(ext: "html"))
    }

    private func keynoteProgram(contents: Data) throws -> ProgramItem {
        ProgramItem(title: "Deck", subtitle: "KEY", sourceURL: try temporaryFile(ext: "key", contents: contents))
    }

    private func activeDeckProgram() -> ProgramItem {
        ProgramItem(title: "Active Deck", subtitle: "KEY")
    }

    private func temporaryFile(ext: String, contents: Data = Data("fixture".utf8)) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try contents.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
