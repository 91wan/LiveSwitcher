import XCTest
@testable import LiveSwitcher

@MainActor
final class LiveRuntimeMediaBridgeTests: XCTestCase {
    func testAVPlayerIsPlayingCallbackUpdatesRuntimeMediaState() {
        var state = LiveRuntimeState()
        state.media.generation = 7

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .mediaPlaybackChanged(isPlaying: true, generation: 7),
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        )

        XCTAssertTrue(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.state.audio.routingContext.isMediaPlaying)
    }

    func testAVPlayerPlaybackEndedDispatchesRuntimeMediaReachedEnd() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let item = mediaProgram()
        viewModel.addProgramItem(item)
        viewModel.switchToProgram(item)
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)

        viewModel.handlePlaybackEnded()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "mediaReachedEnd" })
    }

    func testMediaReachedEndAppliesRuntimeAudioRouting() {
        var state = LiveRuntimeState()
        state.media.generation = 3
        state.media.isPlaying = true

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .mediaReachedEnd(generation: 3),
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        )

        XCTAssertFalse(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.state.media.didPlayToEnd)
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .mediaPlaybackChanged)))
    }

    func testStaleMediaCallbackIsIgnoredByGeneration() {
        var state = LiveRuntimeState()
        state.media.generation = 3

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .mediaPlaybackChanged(isPlaying: true, generation: 2),
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        )

        XCTAssertFalse(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testMediaPlaybackActionProducesPlaybackAndRoutingEffects() {
        var state = LiveRuntimeState()
        state.media.loadedURL = URL(fileURLWithPath: "/tmp/video.mp4")

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorToggledMediaPlayback,
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertTrue(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.effects.contains(.playMedia(generation: state.media.generation)))
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .mediaPlaybackChanged)))
    }

    func testFullRuntimeMediaEffectsUseExplicitFullRuntimeEnvironment() {
        var state = LiveRuntimeState()
        state.media.loadedURL = URL(fileURLWithPath: "/tmp/video.mp4")

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorToggledMediaPlayback,
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertTrue(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.effects.contains(.playMedia(generation: state.media.generation)))
    }

    func testProductionAudioOwnedMediaIntentDoesNotEmitMediaEffects() {
        var state = LiveRuntimeState()
        state.media.loadedURL = URL(fileURLWithPath: "/tmp/video.mp4")

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorToggledMediaPlayback,
            environment: .productionAudioOwned(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertFalse(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testMediaPlaybackCallbackProducesRoutingEffectForCurrentGeneration() {
        var state = LiveRuntimeState()
        state.media.generation = 4

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .mediaPlaybackChanged(isPlaying: true, generation: 4),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertTrue(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .mediaPlaybackChanged)))
    }

    func testFacadeCurrentProgramChangeProducesProgramRoutingEffect() {
        let item = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [item]
        let now = Date(timeIntervalSince1970: 100)

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .facadeCurrentProgramChanged(item.id),
            environment: .fullRuntimeForTests(now: now)
        )

        XCTAssertEqual(mutation.state.program.currentID, item.id)
        XCTAssertEqual(mutation.state.program.currentSwitchedAt, now)
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .programChanged)))
    }

    func testViewModelCurrentProgramItemDidSetRoutesProgramRoutingThroughRuntime() {
        let audioRouting = MediaBridgeAudioRoutingPortSpy()
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, audioRouting: audioRouting),
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        let item = mediaProgram()
        viewModel.programItems = [item]

        viewModel.currentProgramItem = item

        XCTAssertEqual(runtime.state.program.currentID, item.id)
        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "facadeCurrentProgramChanged" })
        XCTAssertEqual(audioRouting.reasons, [.programChanged])
    }

    func testCurrentProgramItemDidSetDoesNotApplyAudioRoutingDirectly() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/ViewModel.swift")

        XCTAssertFalse(source.contains("applyAudioRoutingForRuntimeChange(reason: .programChanged)"))
        XCTAssertTrue(source.contains("dispatchRuntimeFacadeAction(.facadeCurrentProgramChanged(currentProgramItem?.id))"))
    }

    func testMediaPlaybackCallbackRoutesAudioThroughRuntimeOnly() {
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false
        )
        let item = mediaProgram()
        viewModel.addProgramItem(item)
        viewModel.switchToProgram(item)
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        viewModel.resetLastAudioRoutingTransitionForTesting()

        viewModel.avCoordinator.isPlaying = true
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "mediaPlaybackChanged" })
        XCTAssertNotNil(viewModel.lastAudioRoutingTransition)
    }

    func testManualPlaybackToggleRoutesAudioThroughRuntimeOnly() {
        let audioRouting = MediaBridgeAudioRoutingPortSpy()
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, audioRouting: audioRouting),
            environment: .productionAudioOwned()
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        let item = mediaProgram()
        viewModel.programItems = [item]
        viewModel.currentProgramItem = item
        viewModel.avCoordinator.load(url: item.sourceURL!)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        viewModel.avCoordinator.isPlaying = true
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        audioRouting.reset()
        viewModel.resetLastAudioRoutingTransitionForTesting()

        viewModel.toggleMainVideoPlayback()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "operatorToggledMediaPlayback" })
        XCTAssertNil(viewModel.lastAudioRoutingTransition)
    }

    func testRestartCurrentMediaEmitsRuntimeMediaEffectsInMediaOwnedMode() {
        let audioRouting = MediaBridgeAudioRoutingPortSpy()
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, audioRouting: audioRouting),
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        let item = mediaProgram()
        viewModel.programItems = [item]
        viewModel.currentProgramItem = item
        viewModel.programRestartFromBeginningHandler = { onReadyToPlay in
            onReadyToPlay()
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        audioRouting.reset()
        viewModel.resetLastAudioRoutingTransitionForTesting()
        let recordedEffectCount = runtime.recordedEffects.count

        viewModel.restartCurrentMediaFromBeginning()
        let restartEffects = Array(runtime.recordedEffects.dropFirst(recordedEffectCount))

        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "operatorRestartedCurrentMedia" })
        XCTAssertTrue(restartEffects.contains { effect in
            if case .restartMedia = effect { return true }
            return false
        })
        XCTAssertFalse(restartEffects.contains { effect in
            if case .playMedia = effect { return true }
            return false
        })
        XCTAssertEqual(audioRouting.reasons, [.mediaPlaybackChanged])
        XCTAssertNil(viewModel.lastAudioRoutingTransition)
    }

    func testViewModelProgramSwitchDispatchesRuntimeProgramAction() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let item = mediaProgram()
        viewModel.addProgramItem(item)

        viewModel.switchToProgram(item)

        XCTAssertEqual(viewModel.runtime.state.program.currentID, item.id)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedProgram" })
    }

    func testViewModelPlaybackToggleDispatchesRuntimeMediaAction() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let item = mediaProgram()
        viewModel.programItems = [item]
        viewModel.currentProgramItem = item

        viewModel.toggleMainVideoPlayback()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorToggledMediaPlayback" })
    }

    func testViewModelDispatchesThroughInjectedRuntimeStore() {
        let runtime = RuntimeTestFactory.fullRuntimeStore()
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        let item = mediaProgram()
        viewModel.programItems = [item]
        viewModel.currentProgramItem = item

        viewModel.toggleMainVideoPlayback()

        XCTAssertTrue(viewModel.runtime === runtime)
        XCTAssertTrue(runtime.actionLog.contains { $0.actionName == "operatorToggledMediaPlayback" })
        XCTAssertTrue(runtime.recordedEffects.contains(.playMedia(generation: runtime.state.media.generation)))
    }

    func testViewModelRestartDispatchesRuntimeRestartAction() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let item = mediaProgram()
        viewModel.programItems = [item]
        viewModel.currentProgramItem = item

        viewModel.restartCurrentMediaFromBeginning()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorRestartedCurrentMedia" })
    }

    func testViewModelPlaybackEndedDispatchesRuntimeEndCallback() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        let item = mediaProgram()
        viewModel.addProgramItem(item)
        viewModel.switchToProgram(item)
        viewModel.runtime.replaceStateForFacadeSync(viewModel.runtime.state, clearActionLog: true)

        viewModel.handlePlaybackEnded()

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "mediaReachedEnd" })
    }

    private func mediaProgram() -> ProgramItem {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        try? Data("fixture".utf8).write(to: url)
        return ProgramItem(
            title: "Video",
            subtitle: "VIDEO",
            sourceURL: url
        )
    }

    private func sourceText(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

private final class MediaBridgeAudioRoutingPortSpy: AudioRoutingPort {
    private(set) var reasons: [AudioRoutingRuntimeChangeReason] = []

    func apply(reason: AudioRoutingRuntimeChangeReason, state: LiveRuntimeState) {
        reasons.append(reason)
    }

    func reset() {
        reasons = []
    }
}
