import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramActivationSideEffectWiringTests: XCTestCase {
    func testRuntimeExecutionRunsPreSelectionSelectionAndPostSelectionInOrder() throws {
        let current = activeDeckItem()
        let next = keynoteItem()
        let requestID = UUID()
        let harness = makeHarness(requestID: requestID, queuedItems: [current, next], currentItem: current)
        let originalHTML = fileURL("html")
        harness.viewModel.currentHTMLURL = originalHTML
        var events: [String] = []
        harness.viewModel.programActivationSideEffects.stopDeck = {
            events.append("stopDeck:\(harness.runtime.state.program.currentID == current.id)")
        }
        harness.viewModel.programActivationSideEffects.presentKeynote = { _ in
            events.append(
                "presentKeynote:\(harness.viewModel.currentProgramItem?.id == next.id):\(harness.viewModel.currentHTMLURL == nil)"
            )
        }

        let plan = ProgramActivationPlan(
            item: next,
            runtimeSelection: .queued(next.id),
            preSelectionEffects: [.stopDeck],
            postSelectionEffects: [.clearHTML, .presentKeynote(next.sourceURL!)]
        )
        let context = harness.context(recording: { events.append("dispatch:\($0.redactedName)") })

        harness.viewModel.executeProgramActivationPlanFromRuntime(id: requestID, plan: plan, context: context)

        XCTAssertEqual(events, [
            "stopDeck:true",
            "dispatch:operatorSelectedProgram",
            "presentKeynote:true:true",
            "dispatch:programActivationCompleted"
        ])
        XCTAssertNil(harness.runtime.state.programActivation.activeRequestID)
        XCTAssertEqual(harness.runtime.state.programActivation.latestCompletedRequestID, requestID)
    }

    func testInvalidDeckAlertAbortsSelectionAndPostSelectionEffectsButCompletesRequest() {
        let current = activeDeckItem()
        let invalid = keynoteItem()
        let requestID = UUID()
        let harness = makeHarness(requestID: requestID, queuedItems: [current], currentItem: current)
        let originalHTML = fileURL("html")
        harness.viewModel.currentHTMLURL = originalHTML
        var events: [String] = []
        harness.viewModel.programActivationSideEffects.presentInvalidDeckAlert = {
            events.append("invalid:\($0.pathExtension)")
        }
        harness.viewModel.programActivationSideEffects.presentKeynote = { _ in events.append("unexpectedKeynote") }

        let plan = ProgramActivationPlan(
            item: invalid,
            runtimeSelection: nil,
            preSelectionEffects: [.presentInvalidDeckAlert(invalid.sourceURL!)],
            postSelectionEffects: [.clearHTML, .presentKeynote(invalid.sourceURL!)]
        )
        let context = harness.context(recording: { events.append("dispatch:\($0.redactedName)") })

        harness.viewModel.executeProgramActivationPlanFromRuntime(id: requestID, plan: plan, context: context)

        XCTAssertEqual(events, ["invalid:key", "dispatch:programActivationCompleted"])
        XCTAssertEqual(harness.viewModel.currentHTMLURL, originalHTML)
        XCTAssertEqual(harness.runtime.state.program.currentID, current.id)
        XCTAssertNil(harness.runtime.state.programActivation.activeRequestID)
        XCTAssertEqual(harness.runtime.state.programActivation.latestCompletedRequestID, requestID)
    }

    func testHTMLActivationOpensHTMLWithoutPresentationHandlers() {
        let item = htmlItem()
        let requestID = UUID()
        let harness = makeHarness(requestID: requestID, queuedItems: [item])
        var presentationEvents: [String] = []
        harness.viewModel.programActivationSideEffects.presentKeynote = { _ in presentationEvents.append("keynote") }
        harness.viewModel.programActivationSideEffects.openPPTX = { _ in presentationEvents.append("pptx") }
        harness.viewModel.programActivationSideEffects.presentActiveDeck = { presentationEvents.append("activeDeck") }

        let plan = ProgramActivationPlan(
            item: item,
            runtimeSelection: .queued(item.id),
            preSelectionEffects: [],
            postSelectionEffects: [.openHTML(item.sourceURL!)]
        )
        let context = harness.context()

        harness.viewModel.executeProgramActivationPlanFromRuntime(id: requestID, plan: plan, context: context)

        XCTAssertEqual(harness.viewModel.currentHTMLURL, item.sourceURL)
        XCTAssertEqual(harness.viewModel.currentProgramItem?.id, item.id)
        XCTAssertEqual(presentationEvents, [])
        XCTAssertEqual(harness.runtime.state.programActivation.latestCompletedRequestID, requestID)
    }

    func testDetachedMediaActivationDispatchesDetachedSelectionAndClearsViewState() {
        let item = mediaItem()
        let requestID = UUID()
        let harness = makeHarness(requestID: requestID, queuedItems: [])
        harness.viewModel.currentHTMLURL = fileURL("html")
        harness.viewModel.needsMutedMediaStartupAfterClearedProgram = true
        var actions: [String] = []

        let plan = ProgramActivationPlan(
            item: item,
            runtimeSelection: .detached(item),
            preSelectionEffects: [],
            postSelectionEffects: [.clearHTML, .resetMutedMediaStartupFlag]
        )
        let context = harness.context(recording: { actions.append($0.redactedName) })

        harness.viewModel.executeProgramActivationPlanFromRuntime(id: requestID, plan: plan, context: context)

        XCTAssertEqual(actions, ["operatorSelectedDetachedProgram", "programActivationCompleted"])
        XCTAssertEqual(harness.runtime.state.program.currentDetachedItem, item)
        XCTAssertEqual(harness.viewModel.currentProgramItem?.id, item.id)
        XCTAssertNil(harness.viewModel.currentHTMLURL)
        XCTAssertFalse(harness.viewModel.needsMutedMediaStartupAfterClearedProgram)
    }

    func testRejectedRuntimeSelectionDoesNotRunPostSelectionEffectsOrMutateViewOnlyState() {
        let item = keynoteItem()
        let requestID = UUID()
        let harness = makeHarness(requestID: requestID, queuedItems: [])
        let originalHTML = fileURL("html")
        harness.viewModel.currentHTMLURL = originalHTML
        harness.viewModel.needsMutedMediaStartupAfterClearedProgram = true
        var events: [String] = []
        harness.viewModel.programActivationSideEffects.presentKeynote = { _ in events.append("keynote") }
        harness.viewModel.programActivationSideEffects.openPPTX = { _ in events.append("pptx") }
        harness.viewModel.programActivationSideEffects.presentActiveDeck = { events.append("activeDeck") }

        let plan = ProgramActivationPlan(
            item: item,
            runtimeSelection: .queued(item.id),
            preSelectionEffects: [],
            postSelectionEffects: [
                .clearHTML,
                .resetMutedMediaStartupFlag,
                .presentKeynote(item.sourceURL!),
                .openPPTX(fileURL("pptx")),
                .presentActiveDeck
            ]
        )
        let context = harness.context(recording: { events.append("dispatch:\($0.redactedName)") })

        harness.viewModel.executeProgramActivationPlanFromRuntime(id: requestID, plan: plan, context: context)

        XCTAssertEqual(events, ["dispatch:operatorSelectedProgram", "dispatch:programActivationCompleted"])
        XCTAssertEqual(harness.viewModel.currentHTMLURL, originalHTML)
        XCTAssertTrue(harness.viewModel.needsMutedMediaStartupAfterClearedProgram)
        XCTAssertNil(harness.viewModel.currentProgramItem)
        XCTAssertEqual(harness.runtime.state.programActivation.latestCompletedRequestID, requestID)
    }

    func testReadinessConfirmationPassThroughRequestsActivationForReadyMedia() throws {
        let item = ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: try temporaryFile(ext: "mp4"))
        let viewModel = makeInteractiveViewModel(initialItems: [item])

        viewModel.switchToProgramAfterReadinessConfirmation(item)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorRequestedProgramActivation" })
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedProgram" })
        XCTAssertEqual(viewModel.currentProgramItem?.id, item.id)
    }

    private func makeHarness(
        requestID: UUID,
        queuedItems: [ProgramItem],
        currentItem: ProgramItem? = nil
    ) -> ProgramActivationHarness {
        var state = LiveRuntimeState()
        state.programActivation.activeRequestID = requestID
        state.program.items = queuedItems
        state.program.currentID = currentItem?.id
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: .productionProgramActivationOwning()
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults(),
            runtime: runtime
        )
        viewModel.syncProgramQueueFacadeFromRuntime()
        viewModel.syncCurrentProgramFacadeFromRuntime()
        viewModel.programActivationSideEffects.stopDeck = {}
        viewModel.programActivationSideEffects.presentKeynote = { _ in }
        viewModel.programActivationSideEffects.openPPTX = { _ in }
        viewModel.programActivationSideEffects.presentActiveDeck = {}
        viewModel.programActivationSideEffects.presentInvalidDeckAlert = { _ in }
        return ProgramActivationHarness(viewModel: viewModel, runtime: runtime)
    }

    private func makeInteractiveViewModel(initialItems: [ProgramItem]) -> SwitcherViewModel {
        let programActivation = ClosureProgramActivationPort()
        var state = LiveRuntimeState()
        state.program.items = initialItems
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, programActivation: programActivation),
            environment: .productionProgramActivationOwning()
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: userDefaults(),
            runtime: runtime
        )
        programActivation.executeHandler = { [weak viewModel] id, plan, context in
            viewModel?.executeProgramActivationPlanFromRuntime(id: id, plan: plan, context: context)
        }
        viewModel.syncProgramQueueFacadeFromRuntime()
        return viewModel
    }

    private func userDefaults() -> UserDefaults {
        let suiteName = "ProgramActivationSideEffectWiringTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func mediaItem() -> ProgramItem {
        ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: fileURL("mp4"))
    }

    private func htmlItem() -> ProgramItem {
        ProgramItem(title: "HTML", subtitle: "HTML", sourceURL: fileURL("html"))
    }

    private func keynoteItem() -> ProgramItem {
        ProgramItem(title: "Deck", subtitle: "KEY", sourceURL: fileURL("key"))
    }

    private func activeDeckItem() -> ProgramItem {
        ProgramItem(title: "Active Deck", subtitle: "KEY")
    }

    private func fileURL(_ ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
    }

    private func temporaryFile(ext: String, contents: Data = Data("fixture".utf8)) throws -> URL {
        let url = fileURL(ext)
        try contents.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}

@MainActor
private struct ProgramActivationHarness {
    let viewModel: SwitcherViewModel
    let runtime: LiveRuntimeStore

    func context(recording record: @escaping (LiveRuntimeAction) -> Void = { _ in }) -> LiveRuntimeEffectExecutionContext {
        LiveRuntimeEffectExecutionContext(
            currentState: { runtime.state },
            dispatch: { action in
                record(action)
                runtime.dispatch(action)
            }
        )
    }
}
