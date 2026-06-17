import XCTest
@testable import LiveSwitcher

@MainActor
final class MediaPlaybackEndedCallbackAcceptanceTests: XCTestCase {
    func testDispatchRuntimeMediaCallbackReturnsFalseForMissingGeneration() {
        let viewModel = makeViewModel()

        let accepted = viewModel.dispatchRuntimeMediaCallback {
            .mediaReachedEnd(generation: $0)
        }

        XCTAssertFalse(accepted)
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "mediaReachedEnd" })
    }

    func testDispatchRuntimeMediaCallbackReturnsFalseForMismatchedURL() {
        let viewModel = makeViewModel()
        let item = mediaProgram(title: "Current")
        viewModel.addProgramItem(item)
        applyCurrentProgram(item, to: viewModel)
        viewModel.setActiveRuntimeMediaCallbackIdentity(
            generation: viewModel.runtime.state.media.generation,
            url: mediaURL(for: item)
        )
        viewModel.avCoordinator.load(url: mediaURL())
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)

        let accepted = viewModel.dispatchRuntimeMediaCallback {
            .mediaReachedEnd(generation: $0)
        }

        XCTAssertFalse(accepted)
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "mediaReachedEnd" })
    }

    func testDispatchRuntimeMediaCallbackReturnsFalseForNonMediaCurrentProgram() {
        let viewModel = makeViewModel()
        let media = mediaProgram(title: "Media")
        let html = htmlProgram(title: "HTML")
        viewModel.addProgramItems([media, html])
        applyCurrentProgram(html, to: viewModel)
        viewModel.setActiveRuntimeMediaCallbackIdentity(
            generation: viewModel.runtime.state.media.generation,
            url: mediaURL(for: media)
        )
        viewModel.avCoordinator.load(url: mediaURL(for: media))
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)

        let accepted = viewModel.dispatchRuntimeMediaCallback {
            .mediaReachedEnd(generation: $0)
        }

        XCTAssertFalse(accepted)
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "mediaReachedEnd" })
    }

    func testDispatchRuntimeMediaCallbackReturnsTrueWhenGenerationAndURLMatch() {
        let viewModel = makeViewModel()
        let item = mediaProgram(title: "Current")
        viewModel.addProgramItem(item)
        applyCurrentProgram(item, to: viewModel)
        viewModel.setActiveRuntimeMediaCallbackIdentity(
            generation: viewModel.runtime.state.media.generation,
            url: mediaURL(for: item)
        )
        viewModel.avCoordinator.load(url: mediaURL(for: item))
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)

        let accepted = viewModel.dispatchRuntimeMediaCallback {
            .mediaReachedEnd(generation: $0)
        }

        XCTAssertTrue(accepted)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "mediaReachedEnd" })
    }

    func testDispatchRuntimeMediaCallbackIsDiscardableResult() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeFacade.swift")
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "dispatchRuntimeMediaCallback"))

        XCTAssertTrue(source.contains("@discardableResult"))
        XCTAssertTrue(source.contains("func dispatchRuntimeMediaCallback(_ makeAction: (Int) -> LiveRuntimeAction) -> Bool"))
        XCTAssertTrue(body.contains("return false"))
        XCTAssertTrue(body.contains("return true"))
    }

    func testDispatchRuntimeMediaCallbackDoesNotDispatchAudioInputs() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeFacade.swift")
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "dispatchRuntimeMediaCallback"))

        XCTAssertTrue(body.contains("dispatchAudioInputsChanged: false"))
    }

    func testPlaybackEndedDoesNothingWhenRuntimeMediaCallbackRejected() {
        let viewModel = makeViewModel()
        let item = mediaProgram(title: "Current")
        let htmlURL = temporaryURL(ext: "html")
        viewModel.addProgramItem(item)
        applyCurrentProgram(item, to: viewModel)
        viewModel.avCoordinator.load(url: mediaURL())
        viewModel.currentHTMLURL = htmlURL
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)

        viewModel.handlePlaybackEnded()

        XCTAssertEqual(viewModel.currentProgramItem?.id, item.id)
        XCTAssertEqual(viewModel.currentHTMLURL, htmlURL)
        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .playbackReachedEnd })
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "mediaReachedEnd" })
    }

    func testPlaybackEndedDoesNotRecordSupportWhenCallbackRejected() {
        let viewModel = makeRejectedPlaybackEndedViewModel()

        viewModel.handlePlaybackEnded()

        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .playbackReachedEnd })
    }

    func testPlaybackEndedDoesNotClearCurrentProgramWhenCallbackRejected() {
        let viewModel = makeRejectedPlaybackEndedViewModel()
        let currentID = viewModel.currentProgramItem?.id

        viewModel.handlePlaybackEnded()

        XCTAssertEqual(viewModel.currentProgramItem?.id, currentID)
    }

    func testPlaybackEndedDoesNotAutoPlayNextVideoWhenCallbackRejected() {
        let viewModel = makeViewModel()
        let first = mediaProgram(title: "First")
        let second = mediaProgram(title: "Second")
        viewModel.addProgramItems([first, second])
        applyCurrentProgram(first, to: viewModel)
        viewModel.autoPlayNextVideoOnEnd = true
        viewModel.avCoordinator.load(url: mediaURL())
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)

        viewModel.handlePlaybackEnded()

        XCTAssertEqual(viewModel.currentProgramItem?.id, first.id)
    }

    func testPlaybackEndedDoesNotMutatePanicSnapshotWhenCallbackRejected() {
        let viewModel = makeViewModel()
        let item = mediaProgram(title: "Current")
        viewModel.addProgramItem(item)
        applyCurrentProgram(item, to: viewModel)
        viewModel.togglePanicMode()
        let snapshot = viewModel.runtime.state.panic.snapshot
        viewModel.avCoordinator.load(url: mediaURL())
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)

        viewModel.handlePlaybackEnded()

        XCTAssertEqual(viewModel.runtime.state.panic.snapshot, snapshot)
    }

    func testPlaybackEndedStillRecordsSupportWhenCallbackAccepted() {
        let viewModel = makeViewModel()
        let item = mediaProgram(title: "Current")
        viewModel.addProgramItem(item)
        applyCurrentProgram(item, to: viewModel)
        viewModel.setActiveRuntimeMediaCallbackIdentity(
            generation: viewModel.runtime.state.media.generation,
            url: mediaURL(for: item)
        )
        viewModel.avCoordinator.load(url: mediaURL(for: item))

        viewModel.handlePlaybackEnded()

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .playbackReachedEnd })
    }

    func testPlaybackEndedStillClearsCurrentProgramWhenAcceptedAndNoAutoPlay() {
        let viewModel = makeViewModel()
        let item = mediaProgram(title: "Current")
        viewModel.addProgramItem(item)
        applyCurrentProgram(item, to: viewModel)
        viewModel.setActiveRuntimeMediaCallbackIdentity(
            generation: viewModel.runtime.state.media.generation,
            url: mediaURL(for: item)
        )
        viewModel.avCoordinator.load(url: mediaURL(for: item))

        viewModel.handlePlaybackEnded()

        XCTAssertNil(viewModel.currentProgramItem)
    }

    func testHandlePlaybackEndedSourceGatesPostProcessingOnRuntimeCallbackAcceptance() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+MediaPlayback.swift")
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "handlePlaybackEnded"))

        XCTAssertTrue(body.contains("guard dispatchRuntimeMediaCallback"))
    }

    private func makeRejectedPlaybackEndedViewModel() -> SwitcherViewModel {
        let viewModel = makeViewModel()
        let item = mediaProgram(title: "Current")
        viewModel.addProgramItem(item)
        applyCurrentProgram(item, to: viewModel)
        viewModel.avCoordinator.load(url: mediaURL())
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)
        return viewModel
    }

    private func makeViewModel(
        bridgeMode: LiveRuntimeBridgeMode = .panicOwned,
        initialState: LiveRuntimeState = LiveRuntimeState()
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

    private func mediaProgram(title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "VIDEO", sourceURL: mediaURL())
    }

    private func htmlProgram(title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "HTML", sourceURL: temporaryURL(ext: "html"))
    }

    private func applyCurrentProgram(_ item: ProgramItem, to viewModel: SwitcherViewModel) {
        var state = viewModel.runtime.state
        if !state.program.items.contains(where: { $0.id == item.id }) {
            state.program.items.append(item)
        }
        state.program.currentID = item.id
        state.program.currentSwitchedAt = Date(timeIntervalSince1970: 100)
        viewModel.runtime.replaceStateForFacadeSync(state, clearActionLog: false)
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: state.program.currentSwitchedAt)
    }

    private func mediaURL() -> URL {
        temporaryURL(ext: "mp4")
    }

    private func mediaURL(for item: ProgramItem) -> URL {
        guard let sourceURL = item.sourceURL else {
            XCTFail("Expected media test item to have a source URL")
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
