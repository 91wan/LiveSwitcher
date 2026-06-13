import XCTest
@testable import LiveSwitcher

final class ProgramActivationRuntimeViewModelBridgeTests: XCTestCase {
    func testProgramActivationSourceGateStaysInProgramActivationEntryPoint() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivation.swift")

        XCTAssertTrue(source.contains("programSourceIsAvailable(item)"))
        XCTAssertTrue(source.contains("ProgramActivationPlanner.plan("))
        XCTAssertTrue(source.contains(".operatorRequestedProgramActivation"))
    }

    func testProgramActivationRuntimeBridgeDoesNotOwnSourceAvailabilityOrPlanning() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivationRuntimeBridge.swift")

        XCTAssertFalse(source.contains("programSourceIsAvailable"))
        XCTAssertFalse(source.contains("ProgramSourceAvailabilityPolicy"))
        XCTAssertFalse(source.contains("ProgramActivationPlanner.plan"))
        XCTAssertFalse(source.contains("isLikelyValidDeckDocument"))
    }

    func testProgramActivationRuntimeBridgeDispatchesSelectionThroughContextAndCompletes() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivationRuntimeBridge.swift")

        XCTAssertTrue(source.contains("context.dispatch(.operatorSelectedProgram"))
        XCTAssertTrue(source.contains("context.dispatch(.operatorSelectedDetachedProgram"))
        XCTAssertTrue(source.contains("context.dispatch(.programActivationCompleted"))
        XCTAssertFalse(source.contains("dispatchRuntimeFacadeAction"))
    }

    @MainActor
    func testInvalidDeckActivationCompletesActiveRequest() {
        let result = executeInvalidDeckActivation()

        XCTAssertNil(result.runtimeState.programActivation.activeRequestID)
        XCTAssertEqual(result.runtimeState.programActivation.latestCompletedRequestID, result.requestID)
    }

    @MainActor
    func testInvalidDeckActivationDoesNotDispatchSelection() {
        let result = executeInvalidDeckActivation()

        XCTAssertFalse(result.actionNames.contains("operatorSelectedProgram"))
        XCTAssertFalse(result.actionNames.contains("operatorSelectedDetachedProgram"))
    }

    @MainActor
    func testInvalidDeckActivationDoesNotSyncCurrentProgramFacade() {
        let result = executeInvalidDeckActivation()

        XCTAssertNil(result.currentProgramID)
    }

    @MainActor
    func testInvalidDeckActivationDoesNotClearHTML() {
        let htmlURL = fileURL("html")
        let result = executeInvalidDeckActivation(initialHTMLURL: htmlURL)

        XCTAssertEqual(result.currentHTMLURL, htmlURL)
    }

    @MainActor
    func testInvalidDeckActivationDoesNotRunPostSelectionEffects() {
        let result = executeInvalidDeckActivation(post: [.presentKeynote(fileURL("key"))])

        XCTAssertEqual(result.presentedKeynoteURLs, [])
    }

    @MainActor
    private func executeInvalidDeckActivation(
        initialHTMLURL: URL? = nil,
        post: [ProgramActivationPlan.PostSelectionEffect] = []
    ) -> InvalidDeckActivationResult {
        let requestID = UUID()
        let currentItem = ProgramItem(title: "Current", subtitle: "KEY", sourceURL: fileURL("key"))
        var state = LiveRuntimeState()
        state.programActivation.activeRequestID = requestID
        state.program.items = [currentItem]
        state.program.currentID = currentItem.id
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: .productionProgramActivationOwning()
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        viewModel.currentHTMLURL = initialHTMLURL
        var result = InvalidDeckActivationResult(requestID: requestID)
        var actions: [LiveRuntimeAction] = []
        viewModel.programActivationSideEffects.presentKeynote = {
            result.presentedKeynoteURLs.append($0)
        }
        viewModel.programActivationSideEffects.presentInvalidDeckAlert = { _ in }
        let plan = ProgramActivationPlan(
            item: ProgramItem(title: "Invalid", subtitle: "KEY", sourceURL: fileURL("key")),
            runtimeSelection: nil,
            preSelectionEffects: [.presentInvalidDeckAlert(fileURL("key"))],
            postSelectionEffects: post
        )
        let context = LiveRuntimeEffectExecutionContext(
            currentState: { runtime.state },
            dispatch: {
                actions.append($0)
                runtime.dispatch($0)
            }
        )

        viewModel.executeProgramActivationPlanFromRuntime(id: requestID, plan: plan, context: context)

        result.actionNames = actions.map(\.redactedName)
        result.currentHTMLURL = viewModel.currentHTMLURL
        result.currentProgramID = viewModel.currentProgramItem?.id
        result.runtimeState = runtime.state
        return result
    }

    private func fileURL(_ ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
    }
}

private struct InvalidDeckActivationResult {
    let requestID: UUID
    var actionNames: [String] = []
    var currentHTMLURL: URL?
    var currentProgramID: UUID?
    var runtimeState = LiveRuntimeState()
    var presentedKeynoteURLs: [URL] = []
}
