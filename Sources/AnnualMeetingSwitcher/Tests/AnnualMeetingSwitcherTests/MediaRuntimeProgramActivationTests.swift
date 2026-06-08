import XCTest
@testable import LiveSwitcher

@MainActor
final class MediaRuntimeProgramActivationTests: XCTestCase {
    func testSwitchToMediaProgramDispatchesSingleOperatorProgramAction() {
        let media = MediaRuntimeProgramActivationPortSpy()
        let audioRouting = MediaRuntimeProgramActivationAudioRoutingSpy()
        let viewModel = viewModel(media: media, audioRouting: audioRouting)
        let item = mediaProgram()
        viewModel.addProgramItem(item)

        viewModel.switchToProgram(item)

        XCTAssertEqual(actionCount("operatorSelectedProgram", in: viewModel), 1)
        XCTAssertEqual(actionCount("facadeCurrentProgramChanged", in: viewModel), 0)
    }

    func testSwitchToHTMLProgramDispatchesSingleOperatorProgramAction() {
        let media = MediaRuntimeProgramActivationPortSpy()
        let audioRouting = MediaRuntimeProgramActivationAudioRoutingSpy()
        let viewModel = viewModel(media: media, audioRouting: audioRouting)
        let mediaItem = mediaProgram()
        let htmlItem = htmlProgram()
        viewModel.addProgramItems([mediaItem, htmlItem])
        viewModel.switchToProgram(mediaItem)
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)
        audioRouting.reset()

        viewModel.switchToProgram(htmlItem)

        XCTAssertEqual(actionCount("operatorSelectedProgram", in: viewModel), 1)
        XCTAssertEqual(actionCount("facadeCurrentProgramChanged", in: viewModel), 0)
    }

    func testSwitchToKeynoteProgramDispatchesSingleOperatorProgramAction() {
        let media = MediaRuntimeProgramActivationPortSpy()
        let audioRouting = MediaRuntimeProgramActivationAudioRoutingSpy()
        let viewModel = viewModel(media: media, audioRouting: audioRouting)
        let keynoteItem = keynoteProgram()
        viewModel.addProgramItem(keynoteItem)

        viewModel.switchToProgram(keynoteItem)

        XCTAssertEqual(actionCount("operatorSelectedProgram", in: viewModel), 1)
        XCTAssertEqual(actionCount("facadeCurrentProgramChanged", in: viewModel), 0)
    }

    func testCurrentProgramProjectionDoesNotDispatchCompatibilityAction() {
        let item = mediaProgram()
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.applyProgramQueueProjectionFromRuntime([item])

        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())

        XCTAssertEqual(viewModel.currentProgramItem?.id, item.id)
        XCTAssertEqual(actionCount("facadeCurrentProgramChanged", in: viewModel), 0)
    }

    func testProgramSwitchDoesNotDoubleApplyProgramChangedRouting() {
        let media = MediaRuntimeProgramActivationPortSpy()
        let audioRouting = MediaRuntimeProgramActivationAudioRoutingSpy()
        let viewModel = viewModel(media: media, audioRouting: audioRouting)
        let item = mediaProgram()
        viewModel.addProgramItem(item)

        viewModel.switchToProgram(item)

        XCTAssertEqual(audioRouting.reasons.filter { $0 == .programChanged }.count, 1)
    }

    func testProgramQueueStorageIsRuntimeOwnedAndProjectedToViewModel() {
        let item = mediaProgram()
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        viewModel.addProgramItem(item)

        XCTAssertEqual(viewModel.programItems.map(\.id), [item.id])
        XCTAssertEqual(viewModel.runtime.state.program.items.map(\.id), [item.id])
    }

    func testRuntimeDoesNotMutateProgramItemsOnMediaPlaybackToggle() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]
        state.program.currentID = item.id
        state.media.loadedURL = item.sourceURL

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorToggledMediaPlayback,
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        )

        XCTAssertEqual(mutation.state.program.items, [item])
    }

    func testCurrentProgramProjectionDoesNotBackWriteRuntimeOwnedSelection() {
        let item = mediaProgram()
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.applyProgramQueueProjectionFromRuntime([item])

        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())

        XCTAssertEqual(viewModel.currentProgramItem?.id, item.id)
        XCTAssertNil(viewModel.runtime.state.program.currentID)
    }

    func testRuntimeSetsMediaVolumeToZeroBeforeLoadingNewMedia() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedProgram(item.id),
            environment: LiveRuntimeEnvironment(bridgeMode: .programSelectionOwned)
        )

        XCTAssertEqual(mutation.effects.first, .setMediaVolume(0, fade: 0, generation: 1))
    }

    func testRuntimeLoadsMediaBeforePlayMedia() throws {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]

        let effects = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedProgram(item.id),
            environment: LiveRuntimeEnvironment(bridgeMode: .programSelectionOwned)
        ).effects

        let loadIndex = try XCTUnwrap(effects.firstIndex {
            if case .loadMedia = $0 { return true }
            return false
        })
        let playIndex = try XCTUnwrap(effects.firstIndex {
            if case .playMedia = $0 { return true }
            return false
        })

        XCTAssertLessThan(loadIndex, playIndex)
    }

    func testRuntimeDoesNotPlayMediaWhenPanicMirrorIsActive() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]
        state.panic.isActive = true

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedProgram(item.id),
            environment: LiveRuntimeEnvironment(bridgeMode: .programSelectionOwned)
        )

        XCTAssertFalse(mutation.state.media.isPlaying)
        XCTAssertFalse(mutation.effects.contains {
            if case .playMedia = $0 { return true }
            return false
        })
    }

    func testRuntimeAppliesProgramChangedAudioRoutingAfterMediaSelection() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]

        let effects = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedProgram(item.id),
            environment: LiveRuntimeEnvironment(bridgeMode: .programSelectionOwned)
        ).effects

        XCTAssertEqual(effects.last, .applyAudioRouting(reason: .programChanged))
    }

    func testSwitchingToHTMLStopsCurrentMediaThroughRuntime() {
        let item = htmlProgram()
        let media = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [media, item]
        state.program.currentID = media.id
        state.media.loadedURL = media.sourceURL
        state.media.isPlaying = true

        let effects = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedProgram(item.id),
            environment: LiveRuntimeEnvironment(bridgeMode: .programSelectionOwned)
        ).effects

        XCTAssertTrue(effects.contains { effect in
            if case .stopMedia = effect { return true }
            return false
        })
    }

    func testSwitchingToKeynoteStopsCurrentMediaThroughRuntime() {
        let item = keynoteProgram()
        let media = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [media, item]
        state.program.currentID = media.id
        state.media.loadedURL = media.sourceURL
        state.media.isPlaying = true

        let effects = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedProgram(item.id),
            environment: LiveRuntimeEnvironment(bridgeMode: .programSelectionOwned)
        ).effects

        XCTAssertTrue(effects.contains { effect in
            if case .stopMedia = effect { return true }
            return false
        })
    }

    private func viewModel(
        media: MediaRuntimeProgramActivationPortSpy,
        audioRouting: MediaRuntimeProgramActivationAudioRoutingSpy
    ) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, media: media, audioRouting: audioRouting),
            environment: LiveRuntimeEnvironment(bridgeMode: .programSelectionOwned)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        viewModel.actionHandlers.keynotePresentation = { _ in }
        return viewModel
    }

    private func actionCount(_ name: String, in viewModel: SwitcherViewModel) -> Int {
        viewModel.runtime.actionLog.filter { $0.actionName == name }.count
    }

    private func mediaProgram() -> ProgramItem {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        try? Data("fixture".utf8).write(to: url)
        return ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: url)
    }

    private func htmlProgram() -> ProgramItem {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")
        try? Data("<html></html>".utf8).write(to: url)
        return ProgramItem(title: "HTML", subtitle: "HTML", sourceURL: url)
    }

    private func keynoteProgram() -> ProgramItem {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("key")
        try? Data("fixture".utf8).write(to: url)
        return ProgramItem(title: "Deck", subtitle: "KEY", sourceURL: url)
    }
}

private final class MediaRuntimeProgramActivationPortSpy: MediaPlaybackPort {
    func load(url: URL, generation: Int) {}
    func play(generation: Int) {}
    func pause(generation: Int) {}
    func restart(generation: Int) {}
    func seekToStart(generation: Int) {}
    func seekToEnd(generation: Int) {}
    func stop(generation: Int) {}
    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) {}
}

private final class MediaRuntimeProgramActivationAudioRoutingSpy: AudioRoutingPort {
    private(set) var reasons: [AudioRoutingRuntimeChangeReason] = []

    func apply(reason: AudioRoutingRuntimeChangeReason, state: LiveRuntimeState) {
        reasons.append(reason)
    }

    func reset() {
        reasons = []
    }
}
