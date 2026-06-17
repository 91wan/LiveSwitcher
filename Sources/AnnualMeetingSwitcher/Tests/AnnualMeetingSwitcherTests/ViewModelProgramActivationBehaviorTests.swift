import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelProgramActivationBehaviorTests: XCTestCase {
    func testSwitchToMediaDispatchesRuntimeSelectionAndClearsHTML() throws {
        let item = try mediaProgram()
        let viewModel = makeViewModel(initialItems: [item])
        viewModel.currentHTMLURL = try temporaryFile(ext: "html")

        viewModel.switchToProgram(item)

        XCTAssertEqual(viewModel.currentProgramItem?.id, item.id)
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(actionCount("operatorSelectedProgram", in: viewModel), 1)
    }

    func testSwitchToMediaDoesNotRunPresentationHandlers() throws {
        let item = try mediaProgram()
        let viewModel = makeViewModel(initialItems: [item])
        var presentationEvents: [String] = []
        viewModel.programActivationSideEffects.presentKeynote = { _ in presentationEvents.append("keynote") }
        viewModel.programActivationSideEffects.openPPTX = { _ in presentationEvents.append("pptx") }
        viewModel.programActivationSideEffects.presentActiveDeck = { presentationEvents.append("activeDeck") }
        viewModel.programActivationSideEffects.presentInvalidDeckAlert = { _ in presentationEvents.append("invalidDeck") }

        viewModel.switchToProgram(item)

        XCTAssertTrue(presentationEvents.isEmpty)
    }

    func testSwitchToMediaStopsCurrentDeckWhenNeeded() throws {
        let current = activeDeckProgram()
        let item = try mediaProgram()
        let viewModel = makeViewModel(initialItems: [current, item])
        setCurrentProgram(current, in: viewModel)
        var didStopDeck = false
        viewModel.programActivationSideEffects.stopDeck = { didStopDeck = true }

        viewModel.switchToProgram(item)

        XCTAssertTrue(didStopDeck)
    }

    func testSwitchToValidKeynoteDispatchesSelectionBeforeKeynoteHandler() throws {
        let item = try keynoteProgram(contents: Data("fixture".utf8))
        let viewModel = makeViewModel(initialItems: [item])
        var events: [String] = []
        viewModel.programActivationSideEffects.presentKeynote = { url in
            events.append("keynote:\(viewModel.runtime.actionLog.last?.actionName ?? "none"):\(viewModel.currentProgramItem?.id == item.id):\(url == item.sourceURL)")
        }

        viewModel.switchToProgram(item)

        XCTAssertEqual(events, ["keynote:operatorSelectedProgram:true:true"])
    }

    func testSwitchToInvalidKeynoteDoesNotDispatchSelection() throws {
        let item = try keynoteProgram(contents: Data())
        let viewModel = makeViewModel(initialItems: [item])

        viewModel.switchToProgram(item)

        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedProgram" })
    }

    func testSwitchToInvalidKeynoteDoesNotSetCurrentProgram() throws {
        let item = try keynoteProgram(contents: Data())
        let viewModel = makeViewModel(initialItems: [item])

        viewModel.switchToProgram(item)

        XCTAssertNil(viewModel.currentProgramItem)
    }

    func testSwitchToInvalidKeynoteUsesInvalidDeckHandler() throws {
        let item = try keynoteProgram(contents: Data())
        let viewModel = makeViewModel(initialItems: [item])
        var invalidURL: URL?
        viewModel.programActivationSideEffects.presentInvalidDeckAlert = { invalidURL = $0 }

        viewModel.switchToProgram(item)

        XCTAssertEqual(invalidURL, item.sourceURL)
    }

    func testSwitchToValidPPTXDispatchesSelectionBeforePPTXHandler() throws {
        let item = try pptxProgram(contents: Data("fixture".utf8))
        let viewModel = makeViewModel(initialItems: [item])
        var events: [String] = []
        viewModel.programActivationSideEffects.openPPTX = { url in
            events.append("pptx:\(viewModel.runtime.actionLog.last?.actionName ?? "none"):\(viewModel.currentProgramItem?.id == item.id):\(url == item.sourceURL)")
        }

        viewModel.switchToProgram(item)

        XCTAssertEqual(events, ["pptx:operatorSelectedProgram:true:true"])
    }

    func testSwitchToInvalidPPTXDoesNotDispatchSelection() throws {
        let item = try pptxProgram(contents: Data())
        let viewModel = makeViewModel(initialItems: [item])

        viewModel.switchToProgram(item)

        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedProgram" })
    }

    func testSwitchToHTMLDispatchesSelectionAndOpensHTML() throws {
        let item = try htmlProgram()
        let viewModel = makeViewModel(initialItems: [item])

        viewModel.switchToProgram(item)

        XCTAssertEqual(actionCount("operatorSelectedProgram", in: viewModel), 1)
        XCTAssertEqual(viewModel.currentHTMLURL, item.sourceURL)
    }

    func testSwitchToHTMLDoesNotClearHTMLAfterOpening() throws {
        let item = try htmlProgram()
        let viewModel = makeViewModel(initialItems: [item])

        viewModel.switchToProgram(item)

        XCTAssertEqual(viewModel.currentHTMLURL, item.sourceURL)
    }

    func testSwitchToActiveDeckDispatchesSelectionAndUsesActiveDeckHandler() {
        let item = activeDeckProgram()
        let viewModel = makeViewModel(initialItems: [item])
        var didPresent = false
        viewModel.programActivationSideEffects.presentActiveDeck = { didPresent = true }

        viewModel.switchToProgram(item)

        XCTAssertEqual(actionCount("operatorSelectedProgram", in: viewModel), 1)
        XCTAssertTrue(didPresent)
    }

    func testSwitchToAgendaMarkerNoops() {
        let item = ProgramItem.agendaMarker(title: "Break")
        let viewModel = makeViewModel(initialItems: [item])

        viewModel.switchToProgram(item)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertTrue(viewModel.runtime.actionLog.isEmpty)
    }

    func testSwitchToUnsupportedNoops() {
        let item = ProgramItem(title: "Unsupported", subtitle: "TXT")
        let viewModel = makeViewModel(initialItems: [item])

        viewModel.switchToProgram(item)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertTrue(viewModel.runtime.actionLog.isEmpty)
    }

    func testSwitchToDetachedProgramDispatchesDetachedSelection() throws {
        let item = try mediaProgram()
        let viewModel = makeViewModel(initialItems: [])

        viewModel.switchToProgram(item)

        XCTAssertEqual(actionCount("operatorSelectedDetachedProgram", in: viewModel), 1)
        XCTAssertEqual(actionCount("operatorSelectedProgram", in: viewModel), 0)
        XCTAssertEqual(viewModel.runtime.state.program.currentDetachedItem?.id, item.id)
    }

    func testSwitchToQueuedProgramDispatchesQueuedSelection() throws {
        let item = try mediaProgram()
        let viewModel = makeViewModel(initialItems: [item])

        viewModel.switchToProgram(item)

        XCTAssertEqual(actionCount("operatorSelectedProgram", in: viewModel), 1)
        XCTAssertNil(viewModel.runtime.state.program.currentDetachedItem)
    }

    func testSwitchToMissingFileRecordsSupportAndShowsNotice() {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        let item = ProgramItem(title: "Missing", subtitle: "VIDEO", sourceURL: missingURL)
        let viewModel = makeViewModel(initialItems: [item])

        viewModel.switchToProgram(item)

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .programItemFileMissing })
        XCTAssertEqual(viewModel.automationRuntimeNotice?.action, "program.source.missing")
    }

    func testSwitchToMissingURLRecordsSupportAndShowsNoticeForFileBackedLabels() {
        let item = ProgramItem(title: "Missing URL", subtitle: "VIDEO")
        let viewModel = makeViewModel(initialItems: [item])

        viewModel.switchToProgram(item)

        XCTAssertTrue(viewModel.supportEvents.contains { $0.detail == "sourceKind=media,reason=sourceURLMissing" })
        XCTAssertEqual(viewModel.automationRuntimeNotice?.action, "program.source.missing")
    }

    func testMissingPPTURLRecordsPPTXSourceKindSupport() {
        let item = ProgramItem(title: "Slides", subtitle: "PPTX")
        let viewModel = makeViewModel(initialItems: [item])

        viewModel.switchToProgram(item)

        XCTAssertTrue(viewModel.supportEvents.contains { $0.detail == "sourceKind=pptx,reason=sourceURLMissing" })
        XCTAssertEqual(viewModel.automationRuntimeNotice?.action, "program.source.missing")
    }

    func testUnsupportedWithoutFileBackedLabelDoesNotRecordMissingFileSupport() {
        let item = ProgramItem(title: "Unsupported", subtitle: "TXT")
        let viewModel = makeViewModel(initialItems: [item])

        viewModel.switchToProgram(item)

        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .programItemFileMissing })
        XCTAssertNil(viewModel.automationRuntimeNotice)
    }

    private func makeViewModel(initialItems: [ProgramItem]) -> SwitcherViewModel {
        let suiteName = "ViewModelProgramActivationBehaviorTests.\(UUID().uuidString)"
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
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())
        var state = viewModel.runtime.state
        state.program.currentID = item.id
        state.program.currentDetachedItem = nil
        state.program.currentSwitchedAt = Date()
        viewModel.runtime.replaceStateForFacadeSync(state, clearActionLog: true)
    }

    private func actionCount(_ name: String, in viewModel: SwitcherViewModel) -> Int {
        viewModel.runtime.actionLog.filter { $0.actionName == name }.count
    }

    private func mediaProgram(title: String = "Video") throws -> ProgramItem {
        ProgramItem(title: title, subtitle: "VIDEO", sourceURL: try temporaryFile(ext: "mp4"))
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
