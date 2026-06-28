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

    func testPresentationProgramActivationUsesGroupedSideEffectsInOrder() throws {
        let viewModel = makeViewModel()
        let keynote = try deckProgram(extension: "key")
        let pptx = try deckProgram(extension: "pptx")
        var events: [String] = []
        viewModel.programActivationSideEffects.presentKeynote = { events.append("keynote:\($0.pathExtension)") }
        viewModel.programActivationSideEffects.openPPTX = { events.append("pptx:\($0.pathExtension)") }
        viewModel.programActivationSideEffects.stopDeck = { events.append("stopDeck") }
        viewModel.addProgramItems([keynote, pptx])

        viewModel.switchToProgram(keynote)
        viewModel.switchToProgram(pptx)

        XCTAssertEqual(events, ["keynote:key", "stopDeck", "pptx:pptx"])
    }

    func testInvalidDeckStillUsesGroupedActivationSideEffectAndDoesNotSelectProgram() throws {
        let viewModel = makeViewModel()
        let current = ProgramItem(title: "Current Deck", subtitle: "KEY")
        let invalid = try deckProgram(extension: "key", contents: Data())
        var invalidURL: URL?
        var stopCount = 0
        viewModel.programActivationSideEffects.presentInvalidDeckAlert = { invalidURL = $0 }
        viewModel.programActivationSideEffects.stopDeck = { stopCount += 1 }
        viewModel.addProgramItems([current, invalid])
        setCurrentProgram(current, in: viewModel, programItems: [current, invalid])

        viewModel.switchToProgram(invalid)

        XCTAssertEqual(invalidURL, invalid.sourceURL)
        XCTAssertEqual(stopCount, 0)
        XCTAssertEqual(viewModel.currentProgramItem?.id, current.id)
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedProgram" })
    }

    func testMediaTransportActionsDispatchRuntimeActionsWithoutPresentationSideEffects() throws {
        let viewModel = makeViewModel()
        let media = try mediaProgram()
        var presentationEvents: [String] = []
        viewModel.programActivationSideEffects.presentKeynote = { _ in presentationEvents.append("keynote") }
        viewModel.programActivationSideEffects.openPPTX = { _ in presentationEvents.append("pptx") }
        viewModel.programActivationSideEffects.stopDeck = { presentationEvents.append("stopDeck") }
        viewModel.programActivationSideEffects.presentActiveDeck = { presentationEvents.append("activeDeck") }
        setCurrentProgram(media, in: viewModel)

        viewModel.seekProgramItemToStart(media)
        viewModel.seekProgramItemToEnd(media)
        viewModel.returnCurrentMediaToStart()
        viewModel.restartCurrentMediaFromBeginning()

        XCTAssertEqual(actionCount("operatorSeekedCurrentMediaToStart", in: viewModel), 1)
        XCTAssertEqual(actionCount("operatorSeekedCurrentMediaToEnd", in: viewModel), 1)
        XCTAssertEqual(actionCount("operatorReturnedCurrentMediaToStart", in: viewModel), 1)
        XCTAssertEqual(actionCount("operatorRestartedCurrentMedia", in: viewModel), 1)
        XCTAssertEqual(presentationEvents, [])
    }

    func testReturnToStartDoesNotDuplicateRestartDispatchOrSupportEvent() throws {
        let viewModel = makeViewModel()
        let media = try mediaProgram()
        setCurrentProgram(media, in: viewModel)

        viewModel.returnCurrentMediaToStart()

        XCTAssertEqual(actionCount("operatorReturnedCurrentMediaToStart", in: viewModel), 1)
        XCTAssertEqual(actionCount("operatorRestartedCurrentMedia", in: viewModel), 0)
        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .mediaRestarted })
    }

    func testGroupedViewModelTestHooksRemainBehavioralExtensionPoint() {
        let viewModel = makeViewModel()
        var saveCount = 0
        viewModel.testHooks.saveDataDidRun = { saveCount += 1 }

        viewModel.saveData()
        viewModel.saveData()

        XCTAssertEqual(saveCount, 2)
    }

    private func makeViewModel() -> SwitcherViewModel {
        let programActivation = ClosureProgramActivationPort()
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(
                recordsOnly: false,
                programActivation: programActivation
            ),
            environment: .productionProgramActivationOwning()
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: isolatedDefaults(),
            runtime: runtime
        )
        programActivation.executeHandler = { [weak viewModel] id, plan, context in
            viewModel?.executeProgramActivationPlanFromRuntime(id: id, plan: plan, context: context)
        }
        viewModel.programActivationSideEffects.presentKeynote = { _ in }
        viewModel.programActivationSideEffects.openPPTX = { _ in }
        viewModel.programActivationSideEffects.stopDeck = {}
        viewModel.programActivationSideEffects.presentActiveDeck = {}
        viewModel.programActivationSideEffects.presentInvalidDeckAlert = { _ in }
        return viewModel
    }

    private func setCurrentProgram(
        _ item: ProgramItem,
        in viewModel: SwitcherViewModel,
        programItems: [ProgramItem]? = nil,
        mediaIsPlaying: Bool = false
    ) {
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())
        viewModel.runtime.replaceStateForFacadeSync(
            runtimeState(
                for: item,
                programItems: programItems ?? [item],
                mediaIsPlaying: mediaIsPlaying
            ),
            clearActionLog: true
        )
    }

    private func runtimeState(
        for item: ProgramItem,
        programItems: [ProgramItem],
        mediaIsPlaying: Bool
    ) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.program.items = programItems
        state.program.currentID = item.id
        state.media.loadedURL = item.sourceURL
        state.media.isPlaying = mediaIsPlaying
        state.media.duration = 10
        state.audio.routingContext.isCurrentProgramMediaSource = item.sourceKind == .media
        state.audio.routingContext.isMediaPlaying = mediaIsPlaying
        return state
    }

    private func actionCount(_ name: String, in viewModel: SwitcherViewModel) -> Int {
        viewModel.runtime.actionLog.filter { $0.actionName == name }.count
    }

    private func deckProgram(extension pathExtension: String, contents: Data = Data("fixture".utf8)) throws -> ProgramItem {
        ProgramItem(
            title: "Deck",
            subtitle: pathExtension.uppercased(),
            sourceURL: try temporaryFile(ext: pathExtension, contents: contents)
        )
    }

    private func mediaProgram() throws -> ProgramItem {
        ProgramItem(
            title: "Video",
            subtitle: "VIDEO",
            sourceURL: try temporaryFile(ext: "mp4", contents: Data("fixture".utf8))
        )
    }

    private func temporaryFile(ext: String, contents: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try contents.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "ViewModelActionHandlerWiringTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
