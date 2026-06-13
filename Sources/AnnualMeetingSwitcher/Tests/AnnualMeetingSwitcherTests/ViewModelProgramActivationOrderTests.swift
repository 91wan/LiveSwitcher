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
        viewModel.programActivationSideEffects.presentInvalidDeckAlert = { _ in events.append("invalidDeck") }
        viewModel.programActivationSideEffects.stopDeck = { events.append("deckStop") }

        viewModel.switchToProgram(invalid)

        XCTAssertEqual(events, ["invalidDeck"])
    }

    func testInvalidDeckReturnsBeforeRuntimeSelection() throws {
        let invalid = try keynoteProgram(contents: Data())
        let viewModel = makeViewModel(initialItems: [invalid])
        viewModel.programActivationSideEffects.presentInvalidDeckAlert = { _ in }

        viewModel.switchToProgram(invalid)

        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedProgram" })
    }

    func testInvalidDeckReturnsBeforeCurrentProgramProjection() throws {
        let current = activeDeckProgram()
        let invalid = try keynoteProgram(contents: Data())
        let viewModel = makeViewModel(initialItems: [current, invalid])
        setCurrentProgram(current, in: viewModel)
        viewModel.programActivationSideEffects.presentInvalidDeckAlert = { _ in }

        viewModel.switchToProgram(invalid)

        XCTAssertEqual(viewModel.currentProgramItem?.id, current.id)
        XCTAssertNotEqual(viewModel.currentProgramItem?.id, invalid.id)
    }

    func testStopDeckRunsBeforeRuntimeSelection() throws {
        let current = activeDeckProgram()
        let next = try mediaProgram()
        let viewModel = makeViewModel(initialItems: [current, next])
        setCurrentProgram(current, in: viewModel)
        var events: [String] = []
        viewModel.programActivationSideEffects.stopDeck = {
            events.append("deckStop:\(self.actionCount("operatorSelectedProgram", in: viewModel) == 0)")
        }

        viewModel.switchToProgram(next)

        XCTAssertEqual(events, ["deckStop:true"])
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedProgram" })
    }

    func testRuntimeSelectionRunsBeforeCurrentProgramProjection() throws {
        let current = activeDeckProgram()
        let next = try mediaProgram()
        let viewModel = makeViewModel(initialItems: [current, next])
        setCurrentProgram(current, in: viewModel)

        viewModel.switchToProgram(next)

        let firstEntry = try XCTUnwrap(viewModel.runtime.actionLog.first { $0.actionName == "operatorSelectedProgram" })
        XCTAssertEqual(firstEntry.actionName, "operatorSelectedProgram")
        XCTAssertTrue(firstEntry.oldStateSummary.contains(current.id.uuidString))
        XCTAssertFalse(firstEntry.oldStateSummary.contains(next.id.uuidString))
        XCTAssertEqual(viewModel.currentProgramItem?.id, next.id)
    }

    func testCurrentProgramProjectionRunsBeforePostSelectionSideEffects() throws {
        let item = try keynoteProgram(contents: Data("fixture".utf8))
        let viewModel = makeViewModel(initialItems: [item])
        var event: String?
        viewModel.programActivationSideEffects.presentKeynote = { _ in
            event = "keynote:\(viewModel.currentProgramItem?.id == item.id)"
        }

        viewModel.switchToProgram(item)

        XCTAssertEqual(event, "keynote:true")
    }

    func testPostSelectionEffectsRunInPlanOrder() throws {
        let item = try keynoteProgram(contents: Data("fixture".utf8))
        let viewModel = makeViewModel(initialItems: [item])
        viewModel.currentHTMLURL = try temporaryFile(ext: "html")
        var event: String?
        viewModel.programActivationSideEffects.presentKeynote = { _ in
            event = "keynoteAfterClearHTML:\(viewModel.currentHTMLURL == nil)"
        }

        viewModel.switchToProgram(item)

        XCTAssertEqual(event, "keynoteAfterClearHTML:true")
    }

    func testMediaActivationClearHTMLRunsBeforeResetMutedFlag() throws {
        let item = try mediaProgram()
        let viewModel = makeViewModel(initialItems: [item])
        viewModel.currentHTMLURL = try temporaryFile(ext: "html")
        viewModel.needsMutedMediaStartupAfterClearedProgram = true

        viewModel.switchToProgram(item)

        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertFalse(viewModel.needsMutedMediaStartupAfterClearedProgram)
    }

    func testKeynoteActivationClearsHTMLBeforePresentKeynote() throws {
        let item = try keynoteProgram(contents: Data("fixture".utf8))
        let viewModel = makeViewModel(initialItems: [item])
        viewModel.currentHTMLURL = try temporaryFile(ext: "html")
        var htmlWasClearedInHandler = false
        viewModel.programActivationSideEffects.presentKeynote = { _ in
            htmlWasClearedInHandler = viewModel.currentHTMLURL == nil
        }

        viewModel.switchToProgram(item)

        XCTAssertTrue(htmlWasClearedInHandler)
    }

    func testPPTXActivationClearsHTMLBeforeOpenPPTX() throws {
        let item = try pptxProgram(contents: Data("fixture".utf8))
        let viewModel = makeViewModel(initialItems: [item])
        viewModel.currentHTMLURL = try temporaryFile(ext: "html")
        var htmlWasClearedInHandler = false
        viewModel.programActivationSideEffects.openPPTX = { _ in
            htmlWasClearedInHandler = viewModel.currentHTMLURL == nil
        }

        viewModel.switchToProgram(item)

        XCTAssertTrue(htmlWasClearedInHandler)
    }

    func testHTMLActivationDoesNotClearHTMLBeforeOpenHTML() throws {
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
        viewModel.programActivationSideEffects.presentActiveDeck = {
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
        let suiteName = "ViewModelProgramActivationOrderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
        var state = viewModel.runtime.state
        state.program.items = initialItems
        viewModel.runtime.replaceStateForFacadeSync(state, clearActionLog: true)
        viewModel.syncProgramQueueFacadeFromRuntime()
        viewModel.programActivationSideEffects.stopDeck = {}
        viewModel.programActivationSideEffects.presentKeynote = { _ in }
        viewModel.programActivationSideEffects.openPPTX = { _ in }
        viewModel.programActivationSideEffects.presentActiveDeck = {}
        viewModel.programActivationSideEffects.presentInvalidDeckAlert = { _ in }
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

    private func actionCount(_ name: String, in viewModel: SwitcherViewModel) -> Int {
        viewModel.runtime.actionLog.filter { $0.actionName == name }.count
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

    private func pptxProgram(contents: Data) throws -> ProgramItem {
        ProgramItem(title: "Slides", subtitle: "PPTX", sourceURL: try temporaryFile(ext: "pptx", contents: contents))
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
