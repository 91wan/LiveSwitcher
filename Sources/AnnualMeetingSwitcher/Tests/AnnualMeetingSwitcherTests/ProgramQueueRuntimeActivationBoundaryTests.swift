import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramQueueRuntimeActivationBoundaryTests: XCTestCase {
    func testSwitchToProgramStillPerformsSourceAvailabilityCheckInViewModel() throws {
        let source = try programActivationSource()

        XCTAssertTrue(source.contains("programSourceIsAvailable(activationItem)"))
        XCTAssertTrue(source.contains("handleUnavailableProgramSource"))
    }

    func testSwitchToMissingProgramSourceStillRecordsSupportInViewModel() {
        let item = ProgramItem(title: "Missing", subtitle: "MEDIA", sourceURL: URL(fileURLWithPath: "/tmp/missing-\(UUID()).mp4"))
        let viewModel = makeViewModel(initialItems: [item])

        viewModel.switchToProgram(item)

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .programItemFileMissing })
    }

    func testSwitchToInvalidDeckStillUsesInvalidDeckHandler() throws {
        let url = try makeTempFile(ext: "key", contents: Data())
        defer { try? FileManager.default.removeItem(at: url) }
        let item = ProgramItem(title: "Invalid", subtitle: "KEY", sourceURL: url)
        let viewModel = makeViewModel(initialItems: [item])
        var invalidDeckURL: URL?
        viewModel.programActivationSideEffects.presentInvalidDeckAlert = { invalidDeckURL = $0 }

        viewModel.switchToProgram(item)

        XCTAssertEqual(invalidDeckURL, url)
    }

    func testSwitchToKeynoteStillUsesActionHandlerAfterRuntimeSelection() throws {
        let url = try makeTempFile(ext: "key")
        defer { try? FileManager.default.removeItem(at: url) }
        let item = ProgramItem(title: "Deck", subtitle: "KEY", sourceURL: url)
        let viewModel = makeViewModel(initialItems: [item])
        var openedURL: URL?
        viewModel.programActivationSideEffects.presentKeynote = { openedURL = $0 }

        viewModel.switchToProgram(item)

        XCTAssertEqual(openedURL, url)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedProgram" })
    }

    func testSwitchToPPTXStillUsesActionHandlerAfterRuntimeSelection() throws {
        let url = try makeTempFile(ext: "pptx")
        defer { try? FileManager.default.removeItem(at: url) }
        let item = ProgramItem(title: "Deck", subtitle: "PPTX", sourceURL: url)
        let viewModel = makeViewModel(initialItems: [item])
        var openedURL: URL?
        viewModel.programActivationSideEffects.openPPTX = { openedURL = $0 }

        viewModel.switchToProgram(item)

        XCTAssertEqual(openedURL, url)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedProgram" })
    }

    func testSwitchToHTMLStillOpensHTMLThroughViewModel() throws {
        let source = try programActivationRuntimeBridgeSource()

        XCTAssertTrue(source.contains("openHTMLInOutputWindow(url: url)"))
    }

    func testSwitchToActiveDeckStillUsesActionHandler() {
        let item = ProgramItem(title: "Active", subtitle: "KEY (活动)", sourceURL: nil)
        let viewModel = makeViewModel(initialItems: [item])
        var didPresentActiveDeck = false
        viewModel.programActivationSideEffects.presentActiveDeck = { didPresentActiveDeck = true }

        viewModel.switchToProgram(item)

        XCTAssertTrue(didPresentActiveDeck)
    }

    func testProgramQueueReducerDoesNotRunAutomation() {
        let mutation = reduce(.operatorAddedProgramItems([programItem("Added")]))

        XCTAssertFalse(mutation.effects.contains { effect in
            if case .runAppleScript = effect { return true }
            return false
        })
    }

    func testProgramQueueReducerDoesNotOpenHTML() throws {
        let reducer = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift"
        )

        XCTAssertFalse(reducer.contains("openHTMLInOutputWindow"))
        XCTAssertFalse(reducer.contains("currentHTMLURL"))
    }

    func testProgramQueueReducerDoesNotRecordSupport() {
        let mutation = reduce(.operatorRemovedProgramItem(UUID()))

        XCTAssertTrue(mutation.state.support.events.isEmpty)
    }

    private func reduce(_ action: LiveRuntimeAction) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: action,
            environment: .productionProgramSelectionOwning()
        )
    }

    private func programQueueSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramQueue.swift")
    }

    private func programActivationSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivation.swift")
    }

    private func programActivationRuntimeBridgeSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivationRuntimeBridge.swift")
    }

    private func makeViewModel(initialItems: [ProgramItem]) -> SwitcherViewModel {
        var state = LiveRuntimeState()
        state.program.items = initialItems
        let programActivation = ClosureProgramActivationPort()
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: LiveRuntimeEffectRunner(
                recordsOnly: false,
                programActivation: programActivation
            ),
            environment: .productionProgramActivationOwning()
        )
        let suiteName = "ProgramQueueRuntimeActivationBoundaryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults, runtime: runtime)
        programActivation.executeHandler = { [weak viewModel] id, plan, context in
            viewModel?.executeProgramActivationPlanFromRuntime(id: id, plan: plan, context: context)
        }
        viewModel.syncProgramQueueFacadeFromRuntime()
        return viewModel
    }

    private func makeTempFile(ext: String, contents: Data = Data("fixture".utf8)) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(ext)")
        try contents.write(to: url)
        return url
    }

    private func programItem(_ title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "MEDIA", sourceURL: URL(fileURLWithPath: "/tmp/\(title).mp4"))
    }
}
