import XCTest
@testable import LiveSwitcher

@MainActor
final class MediaPlaybackEndedRuntimeSourceTests: XCTestCase {
    func testPlaybackEndedUsesRuntimePanicWhenPanicOwned() {
        let current = mediaProgram(title: "Current")
        var state = acceptedRuntimeState(current: current)
        state.panic.isActive = true
        let viewModel = makeViewModel(bridgeMode: .panicOwned, initialState: state)
        viewModel.applyProgramQueueProjectionFromRuntime([current])
        viewModel.applyCurrentProgramProjectionFromRuntime(current, switchedAt: Date(timeIntervalSince1970: 100))
        viewModel.setActiveRuntimeMediaCallbackIdentity(generation: state.media.generation, url: mediaURL(for: current))
        viewModel.avCoordinator.load(url: mediaURL(for: current))

        viewModel.handlePlaybackEnded()

        XCTAssertEqual(viewModel.currentProgramItem?.id, current.id)
    }

    func testPlaybackEndedUsesFacadePanicWhenPanicNotOwned() {
        let current = mediaProgram(title: "Current")
        var state = acceptedRuntimeState(current: current)
        state.panic.isActive = true
        let viewModel = makeViewModel(bridgeMode: .programActivationOwned, initialState: state)
        viewModel.applyProgramQueueProjectionFromRuntime([current])
        viewModel.applyCurrentProgramProjectionFromRuntime(current, switchedAt: Date(timeIntervalSince1970: 100))
        viewModel.setActiveRuntimeMediaCallbackIdentity(generation: state.media.generation, url: mediaURL(for: current))
        viewModel.avCoordinator.load(url: mediaURL(for: current))

        viewModel.handlePlaybackEnded()

        XCTAssertNil(viewModel.currentProgramItem)
    }

    func testPlaybackEndedUsesRuntimeCurrentProgramWhenProgramSelectionOwned() {
        let staleFacade = mediaProgram(title: "Stale")
        let runtimeCurrent = mediaProgram(title: "Runtime Current")
        var state = acceptedRuntimeState(current: runtimeCurrent)
        state.program.items = [runtimeCurrent]
        state.program.currentID = runtimeCurrent.id
        let viewModel = makeViewModel(bridgeMode: .programSelectionOwned, initialState: state)
        viewModel.applyProgramQueueProjectionFromRuntime([staleFacade])
        viewModel.applyCurrentProgramProjectionFromRuntime(staleFacade, switchedAt: Date(timeIntervalSince1970: 100))
        viewModel.setActiveRuntimeMediaCallbackIdentity(generation: state.media.generation, url: mediaURL(for: runtimeCurrent))
        viewModel.avCoordinator.load(url: mediaURL(for: runtimeCurrent))

        viewModel.handlePlaybackEnded()

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedProgram" })
    }

    func testPlaybackEndedUsesRuntimeProgramQueueWhenProgramQueueOwned() {
        let first = mediaProgram(title: "Runtime First")
        let second = mediaProgram(title: "Runtime Second")
        var state = acceptedRuntimeState(current: first)
        state.program.items = [first, second]
        state.program.currentID = first.id
        state.preferences.autoPlayNextVideoOnEnd = true
        let viewModel = makeViewModel(
            bridgeMode: .panicOwned,
            initialState: state,
            connectProgramActivation: true
        )
        viewModel.applyProgramQueueProjectionFromRuntime([first])
        viewModel.autoPlayNextVideoOnEnd = true
        viewModel.applyCurrentProgramProjectionFromRuntime(first, switchedAt: Date(timeIntervalSince1970: 100))
        viewModel.setActiveRuntimeMediaCallbackIdentity(generation: state.media.generation, url: mediaURL(for: first))
        viewModel.avCoordinator.load(url: mediaURL(for: first))

        viewModel.handlePlaybackEnded()

        XCTAssertEqual(viewModel.currentProgramItem?.id, second.id)
    }

    func testPlaybackEndedUsesRuntimeAutoPlayPreferenceWhenPersistenceOwned() {
        let first = mediaProgram(title: "First")
        let second = mediaProgram(title: "Second")
        var state = acceptedRuntimeState(current: first)
        state.program.items = [first, second]
        state.program.currentID = first.id
        state.preferences.autoPlayNextVideoOnEnd = true
        let viewModel = makeViewModel(
            bridgeMode: .panicOwned,
            initialState: state,
            connectProgramActivation: true
        )
        viewModel.applyProgramQueueProjectionFromRuntime([first, second])
        viewModel.applyCurrentProgramProjectionFromRuntime(first, switchedAt: Date(timeIntervalSince1970: 100))
        viewModel.autoPlayNextVideoOnEnd = false
        viewModel.setActiveRuntimeMediaCallbackIdentity(generation: state.media.generation, url: mediaURL(for: first))
        viewModel.avCoordinator.load(url: mediaURL(for: first))

        viewModel.handlePlaybackEnded()

        XCTAssertEqual(viewModel.currentProgramItem?.id, second.id)
    }

    func testPlaybackEndedDoesNotAutoPlayFromStaleFacadePreferenceWhenPersistenceOwned() {
        let first = mediaProgram(title: "First")
        let second = mediaProgram(title: "Second")
        var state = acceptedRuntimeState(current: first)
        state.program.items = [first, second]
        state.program.currentID = first.id
        state.preferences.autoPlayNextVideoOnEnd = false
        let viewModel = makeViewModel(bridgeMode: .panicOwned, initialState: state)
        viewModel.applyProgramQueueProjectionFromRuntime([first, second])
        viewModel.applyCurrentProgramProjectionFromRuntime(first, switchedAt: Date(timeIntervalSince1970: 100))
        viewModel.autoPlayNextVideoOnEnd = true
        viewModel.setActiveRuntimeMediaCallbackIdentity(generation: state.media.generation, url: mediaURL(for: first))
        viewModel.avCoordinator.load(url: mediaURL(for: first))

        viewModel.handlePlaybackEnded()

        XCTAssertNil(viewModel.currentProgramItem)
    }

    func testPlaybackEndedDoesNotAutoPlayFromStaleFacadeQueueWhenProgramQueueOwned() {
        let first = mediaProgram(title: "First")
        let staleNext = mediaProgram(title: "Stale Next")
        var state = acceptedRuntimeState(current: first)
        state.program.items = [first]
        state.program.currentID = first.id
        state.preferences.autoPlayNextVideoOnEnd = true
        let viewModel = makeViewModel(bridgeMode: .panicOwned, initialState: state)
        viewModel.applyProgramQueueProjectionFromRuntime([first, staleNext])
        viewModel.applyCurrentProgramProjectionFromRuntime(first, switchedAt: Date(timeIntervalSince1970: 100))
        viewModel.autoPlayNextVideoOnEnd = true
        viewModel.setActiveRuntimeMediaCallbackIdentity(generation: state.media.generation, url: mediaURL(for: first))
        viewModel.avCoordinator.load(url: mediaURL(for: first))

        viewModel.handlePlaybackEnded()

        XCTAssertNil(viewModel.currentProgramItem)
    }

    func testPlaybackEndedDoesNotUseStaleFacadeCurrentProgramWhenProgramSelectionOwned() {
        let staleFacade = mediaProgram(title: "Stale")
        let runtimeCurrent = mediaProgram(title: "Runtime Current")
        let runtimeNext = mediaProgram(title: "Runtime Next")
        var state = acceptedRuntimeState(current: runtimeCurrent)
        state.program.items = [runtimeCurrent, runtimeNext]
        state.program.currentID = runtimeCurrent.id
        state.preferences.autoPlayNextVideoOnEnd = true
        let viewModel = makeViewModel(
            bridgeMode: .panicOwned,
            initialState: state,
            connectProgramActivation: true
        )
        viewModel.applyProgramQueueProjectionFromRuntime([staleFacade, runtimeNext])
        viewModel.applyCurrentProgramProjectionFromRuntime(staleFacade, switchedAt: Date(timeIntervalSince1970: 100))
        viewModel.autoPlayNextVideoOnEnd = true
        viewModel.setActiveRuntimeMediaCallbackIdentity(generation: state.media.generation, url: mediaURL(for: runtimeCurrent))
        viewModel.avCoordinator.load(url: mediaURL(for: runtimeCurrent))

        viewModel.handlePlaybackEnded()

        XCTAssertEqual(viewModel.currentProgramItem?.id, runtimeNext.id)
    }

    func testPlaybackEndedAutoPlaysNextRuntimeVideoWhenAcceptedAndEnabled() {
        let first = mediaProgram(title: "First")
        let second = mediaProgram(title: "Second")
        var state = acceptedRuntimeState(current: first)
        state.program.items = [first, second]
        state.program.currentID = first.id
        state.preferences.autoPlayNextVideoOnEnd = true
        let viewModel = makeViewModel(
            bridgeMode: .panicOwned,
            initialState: state,
            connectProgramActivation: true
        )
        viewModel.applyProgramQueueProjectionFromRuntime([first, second])
        viewModel.applyCurrentProgramProjectionFromRuntime(first, switchedAt: Date(timeIntervalSince1970: 100))
        viewModel.setActiveRuntimeMediaCallbackIdentity(generation: state.media.generation, url: mediaURL(for: first))
        viewModel.avCoordinator.load(url: mediaURL(for: first))

        viewModel.handlePlaybackEnded()

        XCTAssertEqual(viewModel.currentProgramItem?.id, second.id)
    }

    func testPlaybackEndedRuntimeSourceHelpersExist() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+MediaPlayback.swift")

        XCTAssertTrue(source.contains("runtimeBackedPanicIsActiveForPlaybackEnded"))
        XCTAssertTrue(source.contains("runtimeBackedCurrentProgramForPlaybackEnded"))
        XCTAssertTrue(source.contains("runtimeBackedProgramItemsForPlaybackEnded"))
        XCTAssertTrue(source.contains("runtimeBackedAutoPlayNextVideoOnEndForPlaybackEnded"))
    }

    private func acceptedRuntimeState(current: ProgramItem) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.program.items = [current]
        state.program.currentID = current.id
        state.media.loadedURL = mediaURL(for: current)
        state.media.generation = 7
        state.media.isPlaying = true
        return state
    }

    private func makeViewModel(
        bridgeMode: LiveRuntimeBridgeMode,
        initialState: LiveRuntimeState,
        connectProgramActivation: Bool = false
    ) -> SwitcherViewModel {
        let programActivation = ClosureProgramActivationPort()
        let runtime = LiveRuntimeStore(
            initialState: initialState,
            effectRunner: LiveRuntimeEffectRunner(
                recordsOnly: !connectProgramActivation,
                programActivation: connectProgramActivation ? programActivation : nil
            ),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        programActivation.executeHandler = { [weak viewModel] id, plan, context in
            viewModel?.executeProgramActivationPlanFromRuntime(id: id, plan: plan, context: context)
        }
        return viewModel
    }

    private func mediaProgram(title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "VIDEO", sourceURL: temporaryURL(ext: "mp4"))
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
