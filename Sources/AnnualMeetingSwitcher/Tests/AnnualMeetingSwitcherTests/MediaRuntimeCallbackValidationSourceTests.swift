import XCTest
@testable import LiveSwitcher

@MainActor
final class MediaRuntimeCallbackValidationSourceTests: XCTestCase {
    func testMediaCallbackValidationUsesRuntimeCurrentProgramWhenProgramSelectionOwned() {
        let runtimeCurrent = mediaProgram(title: "Runtime Current")
        let staleFacade = htmlProgram(title: "Stale Facade")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            initialState: runtimeState(current: runtimeCurrent, generation: 7)
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(staleFacade, switchedAt: Date(timeIntervalSince1970: 100))
        acceptMediaCallback(on: viewModel, item: runtimeCurrent, generation: 7)

        let accepted = viewModel.dispatchRuntimeMediaCallback { .mediaReachedEnd(generation: $0) }

        XCTAssertTrue(accepted)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "mediaReachedEnd" })
    }

    func testMediaCallbackValidationRejectsWhenRuntimeCurrentProgramIsNotMediaEvenIfFacadeIsMedia() {
        let staleMedia = mediaProgram(title: "Stale Media")
        let runtimeHTML = htmlProgram(title: "Runtime HTML")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            initialState: runtimeState(current: runtimeHTML, generation: 7)
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(staleMedia, switchedAt: Date(timeIntervalSince1970: 100))
        acceptMediaCallback(on: viewModel, item: staleMedia, generation: 7)

        let accepted = viewModel.dispatchRuntimeMediaCallback { .mediaReachedEnd(generation: $0) }

        XCTAssertFalse(accepted)
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "mediaReachedEnd" })
    }

    func testMediaCallbackValidationAcceptsWhenRuntimeCurrentProgramIsMediaEvenIfFacadeIsNil() {
        let runtimeCurrent = mediaProgram(title: "Runtime Current")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            initialState: runtimeState(current: runtimeCurrent, generation: 7)
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(nil, switchedAt: nil)
        acceptMediaCallback(on: viewModel, item: runtimeCurrent, generation: 7)

        let accepted = viewModel.dispatchRuntimeMediaCallback { .mediaPlaybackChanged(isPlaying: false, generation: $0) }

        XCTAssertTrue(accepted)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "mediaPlaybackChanged" })
    }

    func testMediaCallbackValidationRejectsWhenRuntimeCurrentProgramURLDiffersFromActiveCallbackURL() {
        let runtimeCurrent = mediaProgram(title: "Runtime Current")
        let staleMedia = mediaProgram(title: "Stale Media")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            initialState: runtimeState(current: runtimeCurrent, generation: 7)
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(staleMedia, switchedAt: Date(timeIntervalSince1970: 100))
        acceptMediaCallback(on: viewModel, item: staleMedia, generation: 7)

        let accepted = viewModel.dispatchRuntimeMediaCallback { .mediaReachedEnd(generation: $0) }

        XCTAssertFalse(accepted)
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "mediaReachedEnd" })
    }

    func testMediaCallbackValidationUsesFacadeCurrentProgramBeforeProgramSelectionOwnership() {
        let facadeCurrent = mediaProgram(title: "Facade Current")
        let viewModel = makeViewModel(
            bridgeMode: .mediaOwned,
            initialState: runtimeState(current: htmlProgram(title: "Runtime HTML"), generation: 7)
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(facadeCurrent, switchedAt: Date(timeIntervalSince1970: 100))
        acceptMediaCallback(on: viewModel, item: facadeCurrent, generation: 7)

        let accepted = viewModel.dispatchRuntimeMediaCallback { .mediaReachedEnd(generation: $0) }

        XCTAssertTrue(accepted)
    }

    func testMediaCallbackValidationRequiresRuntimeMediaGenerationWhenMediaOwned() {
        let runtimeCurrent = mediaProgram(title: "Runtime Current")
        let viewModel = makeViewModel(
            bridgeMode: .mediaOwned,
            initialState: runtimeState(current: runtimeCurrent, generation: 8)
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(runtimeCurrent, switchedAt: Date(timeIntervalSince1970: 100))
        acceptMediaCallback(on: viewModel, item: runtimeCurrent, generation: 8)

        let accepted = viewModel.dispatchRuntimeMediaCallback { .mediaSeekCompleted(time: 12, generation: $0) }

        XCTAssertTrue(accepted)
        XCTAssertEqual(viewModel.runtime.state.media.currentTime, 12)
    }

    func testMediaCallbackValidationRejectsStaleRuntimeMediaGeneration() {
        let runtimeCurrent = mediaProgram(title: "Runtime Current")
        let viewModel = makeViewModel(
            bridgeMode: .mediaOwned,
            initialState: runtimeState(current: runtimeCurrent, generation: 8)
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(runtimeCurrent, switchedAt: Date(timeIntervalSince1970: 100))
        acceptMediaCallback(on: viewModel, item: runtimeCurrent, generation: 7)

        let accepted = viewModel.dispatchRuntimeMediaCallback { .mediaReachedEnd(generation: $0) }

        XCTAssertFalse(accepted)
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "mediaReachedEnd" })
    }

    func testMediaCallbackValidationStillRequiresAVCoordinatorURLMatch() {
        let runtimeCurrent = mediaProgram(title: "Runtime Current")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            initialState: runtimeState(current: runtimeCurrent, generation: 7)
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(runtimeCurrent, switchedAt: Date(timeIntervalSince1970: 100))
        viewModel.setActiveRuntimeMediaCallbackIdentity(generation: 7, url: mediaURL(for: runtimeCurrent))
        viewModel.avCoordinator.load(url: temporaryURL(ext: "mp4"))

        let accepted = viewModel.dispatchRuntimeMediaCallback { .mediaReachedEnd(generation: $0) }

        XCTAssertFalse(accepted)
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "mediaReachedEnd" })
    }

    func testMediaPlaybackEndedRejectedWhenRuntimeCurrentProgramMovedToHTMLButFacadeStillMedia() {
        let staleMedia = mediaProgram(title: "Stale Media")
        let runtimeHTML = htmlProgram(title: "Runtime HTML")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            initialState: runtimeState(current: runtimeHTML, generation: 7)
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(staleMedia, switchedAt: Date(timeIntervalSince1970: 100))
        acceptMediaCallback(on: viewModel, item: staleMedia, generation: 7)

        viewModel.handlePlaybackEnded()

        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .playbackReachedEnd })
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "mediaReachedEnd" })
    }

    func testMediaPlaybackEndedAcceptedWhenRuntimeCurrentProgramMediaAndFacadeStaleNil() {
        let runtimeCurrent = mediaProgram(title: "Runtime Current")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            initialState: runtimeState(current: runtimeCurrent, generation: 7)
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(nil, switchedAt: nil)
        acceptMediaCallback(on: viewModel, item: runtimeCurrent, generation: 7)

        viewModel.handlePlaybackEnded()

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .playbackReachedEnd })
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "mediaReachedEnd" })
    }

    func testMediaCallbackValidationSourceUsesRuntimeBackedHelpers() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "validatedRuntimeMediaCallbackGeneration"))
        let store = try sourceText(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel/Internal/ViewModelRuntimeIdentityStore.swift"
        )

        XCTAssertTrue(source.contains("runtimeBackedCurrentProgramForMediaCallbackValidation"))
        XCTAssertTrue(source.contains("runtimeBackedMediaGenerationForCallbackValidation"))
        XCTAssertTrue(body.contains("runtimeIdentityStore.validatedMediaGeneration"))
        XCTAssertFalse(body.contains("currentProgramItem?.sourceKind == .media"))
        XCTAssertTrue(store.contains("currentProgram.sourceURL == activeMediaURL"))
    }

    private func makeViewModel(
        bridgeMode: LiveRuntimeBridgeMode,
        initialState: LiveRuntimeState
    ) -> SwitcherViewModel {
        SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: LiveRuntimeStore(
                initialState: initialState,
                environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
            )
        )
    }

    private func runtimeState(current item: ProgramItem, generation: Int) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.program.items = [item]
        state.program.currentID = item.id
        state.media.generation = generation
        state.media.loadedURL = item.sourceURL
        state.media.isPlaying = item.sourceKind == .media
        return state
    }

    private func acceptMediaCallback(on viewModel: SwitcherViewModel, item: ProgramItem, generation: Int) {
        viewModel.setActiveRuntimeMediaCallbackIdentity(generation: generation, url: mediaURL(for: item))
        viewModel.avCoordinator.load(url: mediaURL(for: item))
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)
    }

    private func mediaProgram(title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "VIDEO", sourceURL: temporaryURL(ext: "mp4"))
    }

    private func htmlProgram(title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "HTML", sourceURL: temporaryURL(ext: "html"))
    }

    private func mediaURL(for item: ProgramItem) -> URL {
        guard let sourceURL = item.sourceURL else {
            XCTFail("Expected test item to have a source URL")
            return temporaryURL(ext: "mp4")
        }
        return sourceURL
    }

    private func temporaryURL(ext: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try? Data("fixture".utf8).write(to: url)
        return url
    }
}
