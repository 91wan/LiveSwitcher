import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelProgramActivationBehaviorTests: XCTestCase {
    func testSwitchToMediaStillDispatchesRuntimeSelectionAndClearsHTML() throws {
        let item = try tempItem(ext: "mp4")
        let viewModel = makeViewModel(initialItems: [item])
        viewModel.currentHTMLURL = URL(fileURLWithPath: "/tmp/old.html")

        viewModel.switchToProgram(item)

        XCTAssertEqual(actionNames(in: viewModel), ["operatorSelectedProgram"])
        XCTAssertNil(viewModel.currentHTMLURL)
        XCTAssertEqual(viewModel.currentProgramItem, item)
    }

    func testSwitchToMediaStillStopsCurrentDeckWhenNeeded() throws {
        let current = ProgramItem(title: "Deck", subtitle: "KEY")
        let next = try tempItem(ext: "mp4")
        let viewModel = makeViewModel(initialItems: [next])
        viewModel.currentProgramItem = current
        var didStopDeck = false
        viewModel.actionHandlers.deckStop = { didStopDeck = true }

        viewModel.switchToProgram(next)

        XCTAssertTrue(didStopDeck)
    }

    func testSwitchToKeynoteStillValidatesDeckBeforeSelection() throws {
        let item = try tempItem(ext: "key", contents: Data())
        let viewModel = makeViewModel(initialItems: [item])
        var invalidDeckURL: URL?
        viewModel.actionHandlers.invalidDeck = { invalidDeckURL = $0 }

        viewModel.switchToProgram(item)

        XCTAssertEqual(invalidDeckURL, item.sourceURL)
        XCTAssertFalse(actionNames(in: viewModel).contains("operatorSelectedProgram"))
        XCTAssertNil(viewModel.currentProgramItem)
    }

    func testSwitchToInvalidKeynoteDoesNotDispatchRuntimeSelection() throws {
        let item = try tempItem(ext: "key", contents: Data())
        let viewModel = makeViewModel(initialItems: [item])

        viewModel.switchToProgram(item)

        XCTAssertTrue(actionNames(in: viewModel).isEmpty)
    }

    func testSwitchToInvalidKeynoteUsesInvalidDeckHandler() throws {
        let item = try tempItem(ext: "key", contents: Data())
        let viewModel = makeViewModel(initialItems: [item])
        var invalidDeckURL: URL?
        viewModel.actionHandlers.invalidDeck = { invalidDeckURL = $0 }

        viewModel.switchToProgram(item)

        XCTAssertEqual(invalidDeckURL, item.sourceURL)
    }

    func testSwitchToValidKeynoteUsesKeynoteHandlerAfterSelection() throws {
        let item = try tempItem(ext: "key")
        let viewModel = makeViewModel(initialItems: [item])
        var openedURL: URL?
        viewModel.actionHandlers.keynotePresentation = { openedURL = $0 }

        viewModel.switchToProgram(item)

        XCTAssertEqual(actionNames(in: viewModel), ["operatorSelectedProgram"])
        XCTAssertEqual(openedURL, item.sourceURL)
        XCTAssertEqual(viewModel.currentProgramItem, item)
    }

    func testSwitchToPPTXStillUsesPPTXHandlerAfterSelection() throws {
        let item = try tempItem(ext: "pptx")
        let viewModel = makeViewModel(initialItems: [item])
        var openedURL: URL?
        viewModel.actionHandlers.pptxOpen = { openedURL = $0 }

        viewModel.switchToProgram(item)

        XCTAssertEqual(actionNames(in: viewModel), ["operatorSelectedProgram"])
        XCTAssertEqual(openedURL, item.sourceURL)
    }

    func testSwitchToHTMLStillOpensHTMLAfterSelection() throws {
        let item = try tempItem(ext: "html")
        let viewModel = makeViewModel(initialItems: [item])

        viewModel.switchToProgram(item)

        XCTAssertEqual(actionNames(in: viewModel), ["operatorSelectedProgram"])
        XCTAssertEqual(viewModel.currentHTMLURL, item.sourceURL)
    }

    func testSwitchToActiveDeckStillUsesActiveDeckHandlerAfterSelection() {
        let item = ProgramItem(title: "Active", subtitle: "KEY")
        let viewModel = makeViewModel(initialItems: [item])
        var didPresentActiveDeck = false
        viewModel.actionHandlers.activeDeckPresentation = { didPresentActiveDeck = true }

        viewModel.switchToProgram(item)

        XCTAssertEqual(actionNames(in: viewModel), ["operatorSelectedProgram"])
        XCTAssertTrue(didPresentActiveDeck)
    }

    func testSwitchToAgendaMarkerNoops() {
        let viewModel = makeViewModel(initialItems: [])

        viewModel.switchToProgram(.agendaMarker(title: "Break"))

        XCTAssertTrue(actionNames(in: viewModel).isEmpty)
        XCTAssertNil(viewModel.currentProgramItem)
    }

    func testSwitchToUnsupportedNoops() {
        let item = ProgramItem(title: "Unsupported", subtitle: "TXT")
        let viewModel = makeViewModel(initialItems: [item])

        viewModel.switchToProgram(item)

        XCTAssertTrue(actionNames(in: viewModel).isEmpty)
        XCTAssertNil(viewModel.currentProgramItem)
    }

    func testSwitchToDetachedProgramDispatchesDetachedSelection() throws {
        let item = try tempItem(ext: "mp4")
        let viewModel = makeViewModel(initialItems: [])

        viewModel.switchToProgram(item)

        XCTAssertEqual(actionNames(in: viewModel), ["operatorSelectedDetachedProgram"])
    }

    func testSwitchToQueuedProgramDispatchesQueuedSelection() throws {
        let item = try tempItem(ext: "mp4")
        let viewModel = makeViewModel(initialItems: [item])

        viewModel.switchToProgram(item)

        XCTAssertEqual(actionNames(in: viewModel), ["operatorSelectedProgram"])
    }

    func testSwitchToMissingSourceStillRecordsSupportAndNotice() {
        let item = ProgramItem(
            title: "Missing",
            subtitle: "VIDEO",
            sourceURL: URL(fileURLWithPath: "/tmp/missing-\(UUID()).mp4")
        )
        let viewModel = makeViewModel(initialItems: [item])

        viewModel.switchToProgram(item)

        XCTAssertTrue(viewModel.supportEvents.contains { event in
            event.kind == .programItemFileMissing
                && event.detail.contains("sourceKind=media")
                && event.detail.contains("reason=fileMissing")
        })
        XCTAssertEqual(viewModel.automationRuntimeNotice?.action, "program.source.missing")
        XCTAssertFalse(actionNames(in: viewModel).contains("operatorSelectedProgram"))
    }

    func testProgramSourceAvailabilityStillAllowsActiveDeck() {
        let item = ProgramItem(title: "Active", subtitle: "KEY")
        let viewModel = makeViewModel(initialItems: [item])

        viewModel.switchToProgram(item)

        XCTAssertEqual(actionNames(in: viewModel), ["operatorSelectedProgram"])
    }

    func testProgramSourceAvailabilityStillRequiresURLForMedia() {
        let item = ProgramItem(title: "Missing", subtitle: "VIDEO", sourceURL: nil)
        let viewModel = makeViewModel(initialItems: [item])

        viewModel.switchToProgram(item)

        XCTAssertTrue(viewModel.supportEvents.contains { $0.detail.contains("reason=sourceURLMissing") })
        XCTAssertEqual(viewModel.automationRuntimeNotice?.action, "program.source.missing")
    }

    private func makeViewModel(initialItems: [ProgramItem]) -> SwitcherViewModel {
        var state = LiveRuntimeState()
        state.program.items = initialItems
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: .productionProgramQueueOwning()
        )
        let suiteName = "ViewModelProgramActivationBehaviorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults,
            runtime: runtime
        )
        viewModel.syncProgramQueueFacadeFromRuntime()
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)
        return viewModel
    }

    private func actionNames(in viewModel: SwitcherViewModel) -> [String] {
        viewModel.runtime.actionLog.map(\.actionName)
    }

    private func tempItem(ext: String, contents: Data = Data("fixture".utf8)) throws -> ProgramItem {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try contents.write(to: url)
        return ProgramItem(title: ext.uppercased(), subtitle: ext.uppercased(), sourceURL: url)
    }
}
