import XCTest
@testable import LiveSwitcher

@MainActor
final class MediaTransportRuntimeSourceTests: XCTestCase {
    func testToggleMainVideoPlaybackUsesRuntimeCurrentProgramWhenProgramSelectionOwned() {
        let runtimeMedia = mediaProgram(title: "Runtime Media")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            initialState: runtimeState(current: runtimeMedia)
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(nil, switchedAt: nil)

        viewModel.toggleMainVideoPlayback()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorToggledMediaPlayback" })
    }

    func testToggleMainVideoPlaybackReturnsWhenRuntimeCurrentProgramIsNonMediaEvenIfFacadeIsMedia() {
        let staleMedia = mediaProgram(title: "Stale Media")
        let runtimeHTML = htmlProgram(title: "Runtime HTML")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            initialState: runtimeState(current: runtimeHTML)
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(staleMedia, switchedAt: Date(timeIntervalSince1970: 100))

        viewModel.toggleMainVideoPlayback()

        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "operatorToggledMediaPlayback" })
    }

    func testToggleMainVideoPlaybackDispatchesWhenRuntimeCurrentProgramIsMediaEvenIfFacadeIsNil() {
        let runtimeMedia = mediaProgram(title: "Runtime Media")
        let viewModel = makeViewModel(
            bridgeMode: .panicOwned,
            initialState: runtimeState(current: runtimeMedia)
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(nil, switchedAt: nil)

        viewModel.toggleMainVideoPlayback()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorToggledMediaPlayback" })
    }

    func testToggleMainVideoPlaybackUsesRuntimePanicWhenPanicOwned() {
        let runtimeMedia = mediaProgram(title: "Runtime Media")
        var state = runtimeState(current: runtimeMedia, mediaIsPlaying: true)
        state.panic.isActive = true
        let viewModel = makeViewModel(bridgeMode: .panicOwned, initialState: state)
        viewModel.applyCurrentProgramProjectionFromRuntime(runtimeMedia, switchedAt: Date(timeIntervalSince1970: 100))
        viewModel.applyPanicProjectionFromRuntime(isActive: false, snapshot: nil)

        viewModel.toggleMainVideoPlayback()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorPausedMediaForPanic" })
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "operatorToggledMediaPlayback" })
    }

    func testToggleMainVideoPlaybackUsesFacadePanicBeforePanicOwnership() {
        let facadeMedia = mediaProgram(title: "Facade Media")
        let viewModel = makeViewModel(
            bridgeMode: .mediaOwned,
            initialState: runtimeState(current: facadeMedia, mediaIsPlaying: true)
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(facadeMedia, switchedAt: Date(timeIntervalSince1970: 100))
        viewModel.applyPanicProjectionFromRuntime(isActive: true, snapshot: nil)

        viewModel.toggleMainVideoPlayback()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorPausedMediaForPanic" })
    }

    func testToggleMainVideoPlaybackUsesRuntimeMediaPlayingWhenMediaOwned() {
        let runtimeMedia = mediaProgram(title: "Runtime Media")
        var state = runtimeState(current: runtimeMedia, mediaIsPlaying: true)
        state.panic.isActive = true
        let viewModel = makeViewModel(bridgeMode: .panicOwned, initialState: state)
        viewModel.applyCurrentProgramProjectionFromRuntime(runtimeMedia, switchedAt: Date(timeIntervalSince1970: 100))
        viewModel.avCoordinator.isPlaying = false

        viewModel.toggleMainVideoPlayback()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorPausedMediaForPanic" })
    }

    func testTogglePauseUsesRuntimeCurrentProgramWhenProgramSelectionOwned() {
        let runtimeMedia = mediaProgram(title: "Runtime Media")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            initialState: runtimeState(current: runtimeMedia)
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(nil, switchedAt: nil)

        viewModel.togglePause(for: runtimeMedia)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorToggledMediaPlayback" })
    }

    func testTogglePauseSwitchesWhenRuntimeCurrentProgramDiffersEvenIfFacadeMatches() {
        let requested = mediaProgram(title: "Requested")
        let runtimeCurrent = mediaProgram(title: "Runtime Current")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            initialState: runtimeState(current: runtimeCurrent, items: [requested, runtimeCurrent])
        )
        viewModel.applyProgramQueueProjectionFromRuntime([requested, runtimeCurrent])
        viewModel.applyCurrentProgramProjectionFromRuntime(requested, switchedAt: Date(timeIntervalSince1970: 100))

        viewModel.togglePause(for: requested)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorRequestedProgramActivation" })
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "operatorToggledMediaPlayback" })
    }

    func testTogglePauseTogglesWhenRuntimeCurrentProgramMatchesEvenIfFacadeStale() {
        let runtimeMedia = mediaProgram(title: "Runtime Media")
        let staleFacade = htmlProgram(title: "Stale HTML")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            initialState: runtimeState(current: runtimeMedia, items: [runtimeMedia, staleFacade])
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(staleFacade, switchedAt: Date(timeIntervalSince1970: 100))

        viewModel.togglePause(for: runtimeMedia)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorToggledMediaPlayback" })
    }

    func testSeekToStartUsesRuntimeCurrentProgramWhenProgramSelectionOwned() {
        let runtimeMedia = mediaProgram(title: "Runtime Media")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            initialState: runtimeState(current: runtimeMedia)
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(nil, switchedAt: nil)

        viewModel.seekProgramItemToStart(runtimeMedia)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSeekedCurrentMediaToStart" })
    }

    func testSeekToEndUsesRuntimeCurrentProgramWhenProgramSelectionOwned() {
        let runtimeMedia = mediaProgram(title: "Runtime Media")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            initialState: runtimeState(current: runtimeMedia)
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(nil, switchedAt: nil)

        viewModel.seekProgramItemToEnd(runtimeMedia)

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSeekedCurrentMediaToEnd" })
    }

    func testRestartCurrentMediaUsesRuntimeCurrentProgramWhenProgramSelectionOwned() {
        let runtimeMedia = mediaProgram(title: "Runtime Media")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            initialState: runtimeState(current: runtimeMedia)
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(nil, switchedAt: nil)

        viewModel.restartCurrentMediaFromBeginning()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorRestartedCurrentMedia" })
    }

    func testRestartCurrentMediaDoesNotRecordSupportWhenRuntimeCurrentProgramDoesNotSupportSeeking() {
        let staleMedia = mediaProgram(title: "Stale Media")
        let runtimeHTML = htmlProgram(title: "Runtime HTML")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            initialState: runtimeState(current: runtimeHTML)
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(staleMedia, switchedAt: Date(timeIntervalSince1970: 100))

        viewModel.restartCurrentMediaFromBeginning()

        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "operatorRestartedCurrentMedia" })
        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .mediaRestarted })
    }

    func testRestartCurrentMediaRecordsSupportWhenRuntimeCurrentMediaSupportsSeeking() {
        let runtimeMedia = mediaProgram(title: "Runtime Media")
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            initialState: runtimeState(current: runtimeMedia)
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(nil, switchedAt: nil)

        viewModel.restartCurrentMediaFromBeginning()

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .mediaRestarted })
    }

    func testToggleMainVideoPlaybackForRuntimeMediaDispatchesToggle() {
        let runtimeMedia = mediaProgram(title: "Runtime Media")
        let viewModel = makeViewModel(
            bridgeMode: .panicOwned,
            initialState: runtimeState(current: runtimeMedia)
        )

        viewModel.toggleMainVideoPlayback()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorToggledMediaPlayback" })
    }

    func testToggleMainVideoPlaybackForRuntimeDeckStillStopsDeck() {
        let deck = activeDeckProgram()
        let viewModel = makeViewModel(
            bridgeMode: .programSelectionOwned,
            initialState: runtimeState(current: deck)
        )
        viewModel.applyCurrentProgramProjectionFromRuntime(nil, switchedAt: nil)
        var didStopDeck = false
        viewModel.programActivationSideEffects.stopDeck = { didStopDeck = true }

        viewModel.toggleMainVideoPlayback()

        XCTAssertTrue(didStopDeck)
    }

    func testRuntimeBackedMediaTransportHelpersExist() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramMediaTransport.swift"
        )

        XCTAssertTrue(source.contains("runtimeBackedCurrentProgramForMediaTransport"))
        XCTAssertTrue(source.contains("runtimeBackedPanicIsActiveForMediaTransport"))
        XCTAssertTrue(source.contains("runtimeBackedMediaIsPlayingForMediaTransport"))
    }

    private func makeViewModel(
        bridgeMode: LiveRuntimeBridgeMode,
        initialState: LiveRuntimeState
    ) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            initialState: initialState,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        let suiteName = "MediaTransportRuntimeSourceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults,
            runtime: runtime
        )
    }

    private func runtimeState(
        current item: ProgramItem,
        items: [ProgramItem]? = nil,
        mediaIsPlaying: Bool = false
    ) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        let allItems = items ?? [item]
        state.program.items = allItems
        if allItems.contains(where: { $0.id == item.id }) {
            state.program.currentID = item.id
        } else {
            state.program.currentDetachedItem = item
        }
        state.media.loadedURL = item.sourceKind == .media ? item.sourceURL : nil
        state.media.isPlaying = mediaIsPlaying
        state.media.generation = 3
        state.audio.routingContext.isCurrentProgramMediaSource = item.sourceKind == .media
        state.audio.routingContext.isMediaPlaying = mediaIsPlaying
        return state
    }

    private func mediaProgram(title: String) -> ProgramItem {
        ProgramItem(
            title: title,
            subtitle: "VIDEO",
            sourceURL: temporaryFile(ext: "mp4")
        )
    }

    private func htmlProgram(title: String) -> ProgramItem {
        ProgramItem(
            title: title,
            subtitle: "HTML",
            sourceURL: temporaryFile(ext: "html")
        )
    }

    private func activeDeckProgram() -> ProgramItem {
        ProgramItem(title: "Deck", subtitle: "KEY")
    }

    private func temporaryFile(ext: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try? Data("fixture".utf8).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
