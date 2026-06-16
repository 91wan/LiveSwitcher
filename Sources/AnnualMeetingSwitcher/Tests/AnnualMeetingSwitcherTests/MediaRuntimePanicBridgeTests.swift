import XCTest
@testable import LiveSwitcher

@MainActor
final class MediaRuntimePanicBridgeTests: XCTestCase {
    func testPanicActivatePausesMediaThroughRuntimePort() {
        let media = MediaRuntimePanicPortSpy()
        let viewModel = viewModel(media: media)
        let item = mediaProgram()
        viewModel.liveAudioFadeDuration = 0
        viewModel.applyProgramQueueProjectionFromRuntime([item])
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())
        mirrorMediaFacade(for: item, in: viewModel, isPlaying: true)
        viewModel.runtime.replaceStateForFacadeSync(mediaState(for: item, panicActive: false), clearActionLog: true)

        viewModel.togglePanicMode()

        XCTAssertTrue(media.events.contains { $0.hasPrefix("pause:") })
    }

    func testPanicDeactivateResumesMediaThroughRuntimePortWhenSnapshotMatches() {
        let media = MediaRuntimePanicPortSpy()
        let viewModel = viewModel(media: media)
        let item = mediaProgram()
        viewModel.liveAudioFadeDuration = 0
        viewModel.applyProgramQueueProjectionFromRuntime([item])
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())
        viewModel.applyPanicProjectionFromRuntime(
            isActive: true,
            snapshot: PanicPlaybackSnapshot(
                currentProgramID: item.id,
                wasMediaPlaying: true,
                currentBGMID: nil,
                wasBGMPlaying: false
            )
        )

        viewModel.togglePanicMode()

        XCTAssertTrue(media.events.contains { $0.hasPrefix("volume:") && $0.contains(":0.0:") })
        XCTAssertTrue(media.events.contains { $0.hasPrefix("play:") })
    }

    func testPanicDeactivateDoesNotResumeMediaWhenProgramChanged() {
        let media = MediaRuntimePanicPortSpy()
        let viewModel = viewModel(media: media)
        let oldItem = mediaProgram()
        let newItem = mediaProgram()
        viewModel.liveAudioFadeDuration = 0
        viewModel.applyProgramQueueProjectionFromRuntime([oldItem, newItem])
        viewModel.applyCurrentProgramProjectionFromRuntime(newItem, switchedAt: Date())
        viewModel.applyPanicProjectionFromRuntime(
            isActive: true,
            snapshot: PanicPlaybackSnapshot(
                currentProgramID: oldItem.id,
                wasMediaPlaying: true,
                currentBGMID: nil,
                wasBGMPlaying: false
            )
        )

        viewModel.togglePanicMode()

        XCTAssertFalse(media.events.contains { $0.hasPrefix("play:") })
    }

    func testViewModelRestartCurrentMediaDuringPanicDoesNotCallMediaRestartPort() {
        let media = MediaRuntimePanicPortSpy()
        let viewModel = viewModel(media: media, environment: .productionPanicOwning(liveAudioFadeDuration: 0))
        let item = mediaProgram()
        viewModel.applyProgramQueueProjectionFromRuntime([item])
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())
        mirrorMediaFacade(for: item, in: viewModel)
        viewModel.runtime.replaceStateForFacadeSync(panicRestartState(for: item))

        viewModel.restartCurrentMediaFromBeginning()

        XCTAssertFalse(media.events.contains { $0.hasPrefix("restart:") })
    }

    func testViewModelRestartCurrentMediaDuringPanicCallsMediaSeekStartPort() {
        let media = MediaRuntimePanicPortSpy()
        let viewModel = viewModel(media: media, environment: .productionPanicOwning(liveAudioFadeDuration: 0))
        let item = mediaProgram()
        viewModel.applyProgramQueueProjectionFromRuntime([item])
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())
        mirrorMediaFacade(for: item, in: viewModel)
        viewModel.runtime.replaceStateForFacadeSync(panicRestartState(for: item))

        viewModel.restartCurrentMediaFromBeginning()

        XCTAssertTrue(media.events.contains { $0.hasPrefix("seekToStart:") })
    }

    func testViewModelRestartCurrentMediaOutsidePanicStillCallsMediaRestartPort() {
        let media = MediaRuntimePanicPortSpy()
        let viewModel = viewModel(media: media)
        let item = mediaProgram()
        viewModel.applyProgramQueueProjectionFromRuntime([item])
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())
        mirrorMediaFacade(for: item, in: viewModel, isPlaying: true)
        viewModel.runtime.replaceStateForFacadeSync(mediaState(for: item, panicActive: false))

        viewModel.restartCurrentMediaFromBeginning()

        XCTAssertTrue(media.events.contains { $0.hasPrefix("restart:") })
    }

    func testViewModelRestartCurrentMediaDuringPanicDoesNotPlayAVPlayer() {
        let media = MediaRuntimePanicPortSpy()
        let viewModel = viewModel(media: media, environment: .productionPanicOwning(liveAudioFadeDuration: 0))
        let item = mediaProgram()
        viewModel.applyProgramQueueProjectionFromRuntime([item])
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())
        mirrorMediaFacade(for: item, in: viewModel)
        viewModel.runtime.replaceStateForFacadeSync(panicRestartState(for: item))

        viewModel.restartCurrentMediaFromBeginning()

        XCTAssertFalse(media.events.contains { $0.hasPrefix("play:") })
    }

    func testViewModelRestartCurrentMediaDuringPanicStillRecordsSupportEvent() {
        let media = MediaRuntimePanicPortSpy()
        let viewModel = viewModel(media: media, environment: .productionPanicOwning(liveAudioFadeDuration: 0))
        let item = mediaProgram()
        viewModel.applyProgramQueueProjectionFromRuntime([item])
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())
        mirrorMediaFacade(for: item, in: viewModel)
        viewModel.runtime.replaceStateForFacadeSync(panicRestartState(for: item))

        viewModel.restartCurrentMediaFromBeginning()

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .mediaRestarted })
    }

    func testViewModelIsPlayingCallbackDuringPanicDoesNotLeaveRuntimeMediaPlaying() {
        let media = MediaRuntimePanicPortSpy()
        let viewModel = viewModel(media: media, environment: .productionPanicOwning(liveAudioFadeDuration: 0))
        let item = mediaProgram()
        preparePanicMediaCallback(for: item, in: viewModel)

        viewModel.dispatchRuntimeMediaCallback {
            .mediaPlaybackChanged(isPlaying: true, generation: $0)
        }

        XCTAssertFalse(viewModel.runtime.state.media.isPlaying)
        XCTAssertFalse(viewModel.runtime.state.audio.routingContext.isMediaPlaying)
    }

    func testViewModelIsPlayingCallbackDuringPanicDispatchesRuntimePauseEffect() {
        let media = MediaRuntimePanicPortSpy()
        let viewModel = viewModel(media: media, environment: .productionPanicOwning(liveAudioFadeDuration: 0))
        let item = mediaProgram()
        preparePanicMediaCallback(for: item, in: viewModel)

        viewModel.dispatchRuntimeMediaCallback {
            .mediaPlaybackChanged(isPlaying: true, generation: $0)
        }

        XCTAssertTrue(media.events.contains { $0.hasPrefix("pause:") })
    }

    func testViewModelIsPlayingCallbackOutsidePanicStillUpdatesRuntimeMediaPlaying() {
        let media = MediaRuntimePanicPortSpy()
        let viewModel = viewModel(media: media, environment: .productionPanicOwning(liveAudioFadeDuration: 0))
        let item = mediaProgram()
        prepareMediaCallback(for: item, in: viewModel, panicActive: false)

        viewModel.dispatchRuntimeMediaCallback {
            .mediaPlaybackChanged(isPlaying: true, generation: $0)
        }

        XCTAssertTrue(viewModel.runtime.state.media.isPlaying)
        XCTAssertTrue(viewModel.runtime.state.audio.routingContext.isMediaPlaying)
    }

    func testViewModelMediaPlaybackCallbackDoesNotContainPanicSpecialCase() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+MediaPlayback.swift")
        let body = try XCTUnwrap(source.slice(from: "func setupPlayerCoordinator()", to: "func openHTMLInOutputWindow"))

        XCTAssertTrue(body.contains(".mediaPlaybackChanged"))
        XCTAssertFalse(body.contains("isPanicMode"))
        XCTAssertFalse(body.contains("panic"))
        XCTAssertFalse(body.contains("pauseMedia"))
        XCTAssertFalse(body.contains("operatorPausedMediaForPanic"))
    }

    func testPanicDoesNotDirectlyCallAVPlayerForMedia() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Panic.swift")

        XCTAssertFalse(source.contains("avCoordinator.pause()"))
        XCTAssertFalse(source.contains("avCoordinator.play()"))
        XCTAssertFalse(source.contains("avCoordinator.volume = 0"))
    }

    func testPanicDoesNotDirectlyCallBGMPlayers() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+Panic.swift")

        XCTAssertFalse(source.contains("bgmAudioPlayer"))
        XCTAssertFalse(source.contains("bgmFallbackPlayer"))
        XCTAssertTrue(source.contains(".operatorPausedBGMForPanic"))
        XCTAssertTrue(source.contains(".operatorResumedBGMAfterPanic"))
    }

    private func viewModel(
        media: MediaRuntimePanicPortSpy,
        environment: LiveRuntimeEnvironment = LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
    ) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, media: media),
            environment: environment
        )
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
    }

    private func mediaProgram() -> ProgramItem {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        try? Data("fixture".utf8).write(to: url)
        return ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: url)
    }

    private func mirrorMediaFacade(
        for item: ProgramItem,
        in viewModel: SwitcherViewModel,
        isPlaying: Bool = false
    ) {
        viewModel.avCoordinator.currentURL = item.sourceURL
        viewModel.avCoordinator.isPlaying = isPlaying
        viewModel.avCoordinator.currentTime = 10
        viewModel.avCoordinator.duration = 30
    }

    private func panicRestartState(for item: ProgramItem) -> LiveRuntimeState {
        mediaState(for: item, panicActive: true)
    }

    private func preparePanicMediaCallback(for item: ProgramItem, in viewModel: SwitcherViewModel) {
        prepareMediaCallback(for: item, in: viewModel, panicActive: true)
    }

    private func prepareMediaCallback(
        for item: ProgramItem,
        in viewModel: SwitcherViewModel,
        panicActive: Bool
    ) {
        viewModel.applyProgramQueueProjectionFromRuntime([item])
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())
        mirrorMediaFacade(for: item, in: viewModel, isPlaying: panicActive)
        let state = mediaState(for: item, panicActive: panicActive)
        viewModel.runtime.replaceStateForFacadeSync(state, clearActionLog: true)
        viewModel.setActiveRuntimeMediaCallbackIdentity(generation: state.media.generation, url: item.sourceURL!)
        viewModel.applyPanicProjectionFromRuntime(isActive: panicActive, snapshot: state.panic.snapshot)
    }

    private func mediaState(for item: ProgramItem, panicActive: Bool) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.program.items = [item]
        state.program.currentID = item.id
        state.media.loadedURL = item.sourceURL
        state.media.generation = 5
        state.media.isPlaying = !panicActive
        state.media.duration = 30
        state.media.currentTime = 10
        state.panic.isActive = panicActive
        if panicActive {
            state.panic.snapshot = PanicPlaybackSnapshot(
                currentProgramID: item.id,
                wasMediaPlaying: true,
                currentBGMID: nil,
                wasBGMPlaying: false
            )
        }
        return state
    }

    private func sourceText(_ relativePath: String) throws -> String {
        let url = try repositoryRoot().appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            if FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("script/check_release_hygiene.sh").path
            ) {
                return directory
            }
        }
        throw XCTSkip("Could not locate repository root from test source path.")
    }
}

private final class MediaRuntimePanicPortSpy: MediaPlaybackPort {
    private(set) var events: [String] = []

    func load(url: URL, generation: Int) {
        events.append("load:\(generation)")
    }

    func play(generation: Int) {
        events.append("play:\(generation)")
    }

    func pause(generation: Int) {
        events.append("pause:\(generation)")
    }

    func restart(generation: Int) {
        events.append("restart:\(generation)")
    }

    func seekToStart(generation: Int) {
        events.append("seekToStart:\(generation)")
    }

    func seekToEnd(generation: Int) {
        events.append("seekToEnd:\(generation)")
    }

    func stop(generation: Int) {
        events.append("stop:\(generation)")
    }

    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) {
        events.append("volume:\(generation):\(volume):\(fade)")
    }
}
