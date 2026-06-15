import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelProgramMediaTransportBehaviorTests: XCTestCase {
    func testToggleMainVideoPlaybackStillDispatchesMediaToggle() throws {
        let viewModel = makeViewModel()
        let item = try mediaProgram()
        setCurrentProgram(item, in: viewModel)

        viewModel.toggleMainVideoPlayback()

        XCTAssertEqual(actionCount("operatorToggledMediaPlayback", in: viewModel), 1)
    }

    func testToggleMainVideoPlaybackForDeckStillStopsDeck() {
        let viewModel = makeViewModel()
        let item = activeDeckProgram()
        setCurrentProgram(item, in: viewModel)
        var didStopDeck = false
        viewModel.programActivationSideEffects.stopDeck = { didStopDeck = true }

        viewModel.toggleMainVideoPlayback()

        XCTAssertTrue(didStopDeck)
        XCTAssertEqual(actionCount("operatorToggledMediaPlayback", in: viewModel), 0)
    }

    func testToggleMainVideoPlaybackDuringPanicStillPausesRuntimeMedia() throws {
        let viewModel = makeViewModel()
        let item = try mediaProgram()
        setCurrentProgram(item, in: viewModel, mediaIsPlaying: true)
        viewModel.applyPanicProjectionFromRuntime(isActive: true, snapshot: nil)
        viewModel.runtime.replaceStateForFacadeSync(runtimeState(for: item, mediaIsPlaying: true), clearActionLog: true)

        viewModel.toggleMainVideoPlayback()

        XCTAssertEqual(actionCount("operatorPausedMediaForPanic", in: viewModel), 1)
    }

    func testTogglePauseSwitchesToDifferentProgram() throws {
        let viewModel = makeViewModel()
        let current = try mediaProgram(title: "Current")
        let next = try mediaProgram(title: "Next")
        viewModel.applyProgramQueueProjectionFromRuntime([current, next])
        setCurrentProgram(current, in: viewModel, programItems: [current, next])

        viewModel.togglePause(for: next)

        XCTAssertEqual(viewModel.currentProgramItem?.id, next.id)
        XCTAssertEqual(actionCount("operatorSelectedProgram", in: viewModel), 1)
    }

    func testSeekProgramItemToStartStillDispatchesRuntimeSeekStart() throws {
        let viewModel = makeViewModel()
        let item = try mediaProgram()
        setCurrentProgram(item, in: viewModel)

        viewModel.seekProgramItemToStart(item)

        XCTAssertEqual(actionCount("operatorSeekedCurrentMediaToStart", in: viewModel), 1)
    }

    func testSeekProgramItemToEndStillDispatchesRuntimeSeekEnd() throws {
        let viewModel = makeViewModel()
        let item = try mediaProgram()
        setCurrentProgram(item, in: viewModel)

        viewModel.seekProgramItemToEnd(item)

        XCTAssertEqual(actionCount("operatorSeekedCurrentMediaToEnd", in: viewModel), 1)
    }

    func testRestartCurrentMediaStillDispatchesRuntimeRestartAndRecordsSupport() throws {
        let viewModel = makeViewModel()
        let item = try mediaProgram()
        setCurrentProgram(item, in: viewModel)

        viewModel.restartCurrentMediaFromBeginning()

        XCTAssertEqual(actionCount("operatorRestartedCurrentMedia", in: viewModel), 1)
        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .mediaRestarted })
    }

    func testTransportNoopsForUnsupportedSources() {
        let viewModel = makeViewModel()
        let item = ProgramItem(title: "Unsupported", subtitle: "TXT")
        setCurrentProgram(item, in: viewModel)

        viewModel.seekProgramItemToStart(item)
        viewModel.seekProgramItemToEnd(item)
        viewModel.restartCurrentMediaFromBeginning()
        viewModel.toggleMainVideoPlayback()

        XCTAssertTrue(viewModel.runtime.actionLog.isEmpty)
        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .mediaRestarted })
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
        let suiteName = "ViewModelProgramMediaTransportBehaviorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults,
            runtime: runtime
        )
        programActivation.executeHandler = { [weak viewModel] id, plan, context in
            viewModel?.executeProgramActivationPlanFromRuntime(id: id, plan: plan, context: context)
        }
        viewModel.programActivationSideEffects.stopDeck = {}
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
        programItems: [ProgramItem]? = nil,
        mediaIsPlaying: Bool
    ) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.program.items = programItems ?? [item]
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

    private func mediaProgram(title: String = "Video") throws -> ProgramItem {
        ProgramItem(title: title, subtitle: "VIDEO", sourceURL: try temporaryFile(ext: "mp4"))
    }

    private func activeDeckProgram() -> ProgramItem {
        ProgramItem(title: "Active Deck", subtitle: "KEY")
    }

    private func temporaryFile(ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try Data("fixture".utf8).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
