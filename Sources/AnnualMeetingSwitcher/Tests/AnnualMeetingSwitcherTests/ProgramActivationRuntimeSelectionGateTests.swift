import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramActivationRuntimeSelectionGateTests: XCTestCase {
    func testRejectedQueuedSelectionDoesNotRunPostSelectionEffects() {
        let result = executeQueuedSelection(isAccepted: false, post: [
            .clearHTML,
            .presentKeynote(fileURL("key")),
            .openPPTX(fileURL("pptx")),
            .openHTML(fileURL("html")),
            .presentActiveDeck
        ])

        XCTAssertEqual(result.postSelectionEventCount, 0)
    }

    func testRejectedQueuedSelectionDoesNotClearHTML() {
        let originalURL = fileURL("html")
        let result = executeQueuedSelection(isAccepted: false, initialHTMLURL: originalURL, post: [.clearHTML])

        XCTAssertEqual(result.currentHTMLURL, originalURL)
    }

    func testRejectedQueuedSelectionDoesNotPresentKeynote() {
        let result = executeQueuedSelection(isAccepted: false, post: [.presentKeynote(fileURL("key"))])

        XCTAssertEqual(result.presentedKeynoteURLs, [])
    }

    func testRejectedQueuedSelectionDoesNotOpenPPTX() {
        let result = executeQueuedSelection(isAccepted: false, post: [.openPPTX(fileURL("pptx"))])

        XCTAssertEqual(result.openedPPTXURLs, [])
    }

    func testRejectedQueuedSelectionDoesNotOpenHTML() {
        let result = executeQueuedSelection(isAccepted: false, post: [.openHTML(fileURL("html"))])

        XCTAssertNil(result.currentHTMLURL)
    }

    func testRejectedQueuedSelectionDoesNotPresentActiveDeck() {
        let result = executeQueuedSelection(isAccepted: false, post: [.presentActiveDeck])

        XCTAssertEqual(result.activeDeckCount, 0)
    }

    func testRejectedQueuedSelectionStillCompletesActiveRequest() {
        let result = executeQueuedSelection(isAccepted: false, post: [.presentKeynote(fileURL("key"))])

        XCTAssertEqual(result.runtimeState.programActivation.activeRequestID, nil)
        XCTAssertEqual(result.runtimeState.programActivation.latestCompletedRequestID, result.requestID)
    }

    func testAcceptedQueuedSelectionRunsPostSelectionEffects() {
        let result = executeQueuedSelection(isAccepted: true, post: [
            .presentKeynote(fileURL("key")),
            .openPPTX(fileURL("pptx")),
            .presentActiveDeck
        ])

        XCTAssertEqual(result.postSelectionEventCount, 3)
    }

    func testAcceptedDetachedSelectionRunsPostSelectionEffects() {
        let item = ProgramItem(title: "Detached", subtitle: "HTML", sourceURL: fileURL("html"))
        let result = executeActivation(
            item: item,
            queuedItems: [],
            selection: .detached(item),
            post: [.openHTML(fileURL("html"))]
        )

        XCTAssertNotNil(result.currentHTMLURL)
    }

    func testSelectionConfirmationUsesRuntimeEffectiveCurrentItem() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivationRuntimeBridge.swift")

        XCTAssertTrue(source.contains("context.currentState().program.effectiveCurrentItem?.id == expectedItemID"))
    }

    private func executeQueuedSelection(
        isAccepted: Bool,
        initialHTMLURL: URL? = nil,
        post: [ProgramActivationPlan.PostSelectionEffect]
    ) -> SelectionGateResult {
        let item = ProgramItem(title: "Queued", subtitle: "KEY", sourceURL: fileURL("key"))
        return executeActivation(
            item: item,
            queuedItems: isAccepted ? [item] : [],
            selection: .queued(item.id),
            initialHTMLURL: initialHTMLURL,
            post: post
        )
    }

    private func executeActivation(
        item: ProgramItem,
        queuedItems: [ProgramItem],
        selection: ProgramActivationPlan.RuntimeSelection,
        initialHTMLURL: URL? = nil,
        post: [ProgramActivationPlan.PostSelectionEffect]
    ) -> SelectionGateResult {
        let requestID = UUID()
        var state = LiveRuntimeState()
        state.programActivation.activeRequestID = requestID
        state.program.items = queuedItems
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
        var result = SelectionGateResult(requestID: requestID)

        viewModel.programActivationSideEffects.presentKeynote = {
            result.presentedKeynoteURLs.append($0)
        }
        viewModel.programActivationSideEffects.openPPTX = {
            result.openedPPTXURLs.append($0)
        }
        viewModel.programActivationSideEffects.presentActiveDeck = {
            result.activeDeckCount += 1
        }

        let plan = ProgramActivationPlan(
            item: item,
            runtimeSelection: selection,
            preSelectionEffects: [],
            postSelectionEffects: post
        )
        let context = LiveRuntimeEffectExecutionContext(
            currentState: { runtime.state },
            dispatch: { runtime.dispatch($0) }
        )

        viewModel.executeProgramActivationPlanFromRuntime(id: requestID, plan: plan, context: context)

        result.currentHTMLURL = viewModel.currentHTMLURL
        result.runtimeState = runtime.state
        return result
    }

    private func fileURL(_ ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
    }
}

private struct SelectionGateResult {
    let requestID: UUID
    var presentedKeynoteURLs: [URL] = []
    var openedPPTXURLs: [URL] = []
    var activeDeckCount = 0
    var currentHTMLURL: URL?
    var runtimeState = LiveRuntimeState()

    init(requestID: UUID = UUID()) {
        self.requestID = requestID
    }

    var postSelectionEventCount: Int {
        presentedKeynoteURLs.count
            + openedPPTXURLs.count
            + activeDeckCount
            + (currentHTMLURL == nil ? 0 : 1)
    }
}
