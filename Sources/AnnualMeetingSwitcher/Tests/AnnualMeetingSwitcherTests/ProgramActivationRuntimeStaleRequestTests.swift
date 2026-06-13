import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramActivationRuntimeStaleRequestTests: XCTestCase {
    func testStaleActivationEffectDoesNotRunStopDeck() {
        let result = executeStaleActivation(plan: plan(pre: [.stopDeck]))

        XCTAssertEqual(result.stopDeckCount, 0)
    }

    func testStaleActivationEffectDoesNotPresentKeynote() {
        let result = executeStaleActivation(plan: plan(post: [.presentKeynote(fileURL("key"))]))

        XCTAssertEqual(result.presentedKeynoteURLs, [])
    }

    func testStaleActivationEffectDoesNotOpenPPTX() {
        let result = executeStaleActivation(plan: plan(post: [.openPPTX(fileURL("pptx"))]))

        XCTAssertEqual(result.openedPPTXURLs, [])
    }

    func testStaleActivationEffectDoesNotOpenHTML() {
        let result = executeStaleActivation(plan: plan(post: [.openHTML(fileURL("html"))]))

        XCTAssertNil(result.currentHTMLURL)
    }

    func testStaleActivationEffectDoesNotPresentActiveDeck() {
        let result = executeStaleActivation(plan: plan(post: [.presentActiveDeck]))

        XCTAssertEqual(result.activeDeckCount, 0)
    }

    func testStaleActivationEffectDoesNotShowInvalidDeckAlert() {
        let result = executeStaleActivation(plan: plan(pre: [.presentInvalidDeckAlert(fileURL("key"))], selection: nil))

        XCTAssertEqual(result.invalidDeckURLs, [])
    }

    func testStaleActivationEffectDoesNotDispatchSelection() {
        let result = executeStaleActivation(plan: plan(post: [.presentActiveDeck]))

        XCTAssertFalse(result.actions.contains { $0.redactedName == "operatorSelectedProgram" })
        XCTAssertFalse(result.actions.contains { $0.redactedName == "operatorSelectedDetachedProgram" })
    }

    func testStaleActivationEffectDoesNotDispatchCompleted() {
        let staleID = UUID()
        let result = executeStaleActivation(id: staleID, plan: plan(pre: [.stopDeck]))

        XCTAssertFalse(result.actions.contains(.programActivationCompleted(id: staleID)))
    }

    func testOldActivationCompletionDoesNotClearNewerActiveRequest() {
        let staleID = UUID()
        let activeID = UUID()
        var state = LiveRuntimeState()
        state.programActivation.activeRequestID = activeID

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .programActivationCompleted(id: staleID),
            environment: .productionProgramActivationOwning()
        )

        XCTAssertEqual(mutation.state.programActivation.activeRequestID, activeID)
        XCTAssertNil(mutation.state.programActivation.latestCompletedRequestID)
    }

    func testActivationEffectChecksActiveRequestBeforeSideEffects() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivationRuntimeBridge.swift")
        let guardRange = try XCTUnwrap(source.range(of: "context.currentState().programActivation.activeRequestID == id"))
        let preSelectionRange = try XCTUnwrap(source.range(of: "for effect in plan.preSelectionEffects"))

        XCTAssertLessThan(guardRange.lowerBound, preSelectionRange.lowerBound)
    }

    private func executeStaleActivation(
        id: UUID = UUID(),
        plan: ProgramActivationPlan
    ) -> StaleActivationResult {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        var result = StaleActivationResult()
        let activeID = UUID()
        var state = LiveRuntimeState()
        state.programActivation.activeRequestID = activeID
        state.program.items = [plan.item]
        viewModel.runtime.replaceStateForFacadeSync(state)

        viewModel.programActivationSideEffects.stopDeck = {
            result.stopDeckCount += 1
        }
        viewModel.programActivationSideEffects.presentKeynote = {
            result.presentedKeynoteURLs.append($0)
        }
        viewModel.programActivationSideEffects.openPPTX = {
            result.openedPPTXURLs.append($0)
        }
        viewModel.programActivationSideEffects.presentActiveDeck = {
            result.activeDeckCount += 1
        }
        viewModel.programActivationSideEffects.presentInvalidDeckAlert = {
            result.invalidDeckURLs.append($0)
        }

        let context = LiveRuntimeEffectExecutionContext(
            currentState: { viewModel.runtime.state },
            dispatch: { action in
                result.actions.append(action)
                viewModel.runtime.dispatch(action)
            }
        )

        viewModel.executeProgramActivationPlanFromRuntime(id: id, plan: plan, context: context)
        result.currentHTMLURL = viewModel.currentHTMLURL
        return result
    }

    private func plan(
        pre: [ProgramActivationPlan.PreSelectionEffect] = [],
        post: [ProgramActivationPlan.PostSelectionEffect] = [],
        selection: ProgramActivationPlan.RuntimeSelection? = nil
    ) -> ProgramActivationPlan {
        let item = ProgramItem(title: "Program", subtitle: "KEY", sourceURL: fileURL("key"))
        return ProgramActivationPlan(
            item: item,
            runtimeSelection: selection ?? .queued(item.id),
            preSelectionEffects: pre,
            postSelectionEffects: post
        )
    }

    private func fileURL(_ ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
    }
}

private struct StaleActivationResult {
    var stopDeckCount = 0
    var presentedKeynoteURLs: [URL] = []
    var openedPPTXURLs: [URL] = []
    var activeDeckCount = 0
    var invalidDeckURLs: [URL] = []
    var actions: [LiveRuntimeAction] = []
    var currentHTMLURL: URL?
}
