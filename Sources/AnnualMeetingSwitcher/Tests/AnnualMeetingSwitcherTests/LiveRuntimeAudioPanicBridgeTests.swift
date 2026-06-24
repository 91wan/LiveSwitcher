import XCTest
@testable import LiveSwitcher

@MainActor
final class LiveRuntimeAudioPanicBridgeTests: XCTestCase {
    func testAudioVolumeActionProducesFaderRoutingEffect() {
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorChangedMasterVolume(0.82),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertEqual(mutation.state.audio.masterVolume, 0.82, accuracy: 0.0001)
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .operatorFaderChanged)))
    }

    func testAudioStrategyActionProducesStrategyRoutingAndPersistenceEffects() {
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorSelectedAudioStrategy(.bgmOnly),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertEqual(mutation.state.audio.strategy, AudioStrategy.bgmOnly)
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .strategyChanged)))
        XCTAssertTrue(mutation.effects.contains(.saveAudioStrategy(.bgmOnly)))
    }

    func testSpeakerActionProducesSpeakerRoutingAndPersistenceEffects() {
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorSetSpeakerMode(true),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertTrue(mutation.state.audio.isSpeakerMode)
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .speakerChanged)))
        XCTAssertTrue(mutation.effects.contains(.saveSpeakerMode(true)))
    }

    func testRuntimeAudioStateUsesRoutingEngineForStrategyAndSpeakerMode() {
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let video = ProgramItem(
            title: "Opening",
            subtitle: "VIDEO",
            sourceURL: temporaryDirectory.appendingPathComponent("opening.mp4")
        )
        let bgm = BGMItem(
            title: "Walk In",
            url: temporaryDirectory.appendingPathComponent("walk-in.mp3"),
            category: .warmUp
        )
        var state = LiveRuntimeState()
        state.program.items = [video]
        state.program.currentID = video.id
        state.media.loadedURL = video.sourceURL
        state.media.isPlaying = true
        state.bgm.items = [bgm]
        state.bgm.currentID = bgm.id
        state.bgm.phase = .playing
        state.audio.masterVolume = 0.8
        state.audio.mediaVolume = 0.5
        state.audio.bgmVolume = 0.25
        state.audio.strategy = .mixed

        let speaker = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSetSpeakerMode(true),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )
        XCTAssertEqual(speaker.state.audio.effectiveMedia, 0.056, accuracy: 0.0001)
        XCTAssertEqual(speaker.state.audio.effectiveBGM, 0.056, accuracy: 0.0001)

        let followProgram = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedAudioStrategy(.followProgram),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )
        XCTAssertEqual(followProgram.state.audio.effectiveMedia, 0.4, accuracy: 0.0001)
        XCTAssertEqual(followProgram.state.audio.effectiveBGM, 0, accuracy: 0.0001)

        let bgmOnly = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedAudioStrategy(.bgmOnly),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )
        XCTAssertEqual(bgmOnly.state.audio.effectiveMedia, 0, accuracy: 0.0001)
        XCTAssertEqual(bgmOnly.state.audio.effectiveBGM, 0.2, accuracy: 0.0001)
    }

    func testLimiterActionsProduceLimiterOrFaderRoutingEffects() {
        let muted = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorChangedMediaMute(true),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )
        let takeover = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorChangedBGMTakeover(true),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertTrue(muted.state.audio.isMediaMuted)
        XCTAssertTrue(muted.effects.contains(.applyAudioRouting(reason: .operatorFaderChanged)))
        XCTAssertTrue(takeover.state.audio.isBGMTakeoverActive)
        XCTAssertTrue(takeover.effects.contains(.applyAudioRouting(reason: .limiterChanged)))
    }

    func testPanicActionProducesPanicRoutingEffect() {
        var state = LiveRuntimeState()
        state.media.isPlaying = true
        state.bgm.phase = .playing
        state.bgm.currentID = state.bgm.items.first?.id

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSetPanic(true),
            environment: .fullRuntimeForTests(now: Date(timeIntervalSince1970: 100))
        )

        XCTAssertTrue(mutation.state.panic.isActive)
        XCTAssertEqual(mutation.state.audio.effectiveMedia, 0)
        XCTAssertEqual(mutation.state.audio.effectiveBGM, 0)
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .panicChanged)))
    }

    func testViewModelAudioSettersDispatchRuntimeActionsAndApplyRuntimeTransition() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        viewModel.masterVolume = 0.73

        XCTAssertEqual(viewModel.runtime.state.audio.masterVolume, 0.73, accuracy: 0.0001)
        XCTAssertEqual(viewModel.runtime.actionLog.last?.actionName, "operatorChangedMasterVolume")
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .operatorFaderChanged)
    }

    func testViewModelSpeakerToggleDispatchesRuntimeActionAndAppliesRuntimeTransition() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        viewModel.toggleSpeakerMode()

        XCTAssertTrue(viewModel.runtime.state.audio.isSpeakerMode)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSetSpeakerMode" })
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "supportEventRecorded" })
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .speakerChanged)
    }

    func testViewModelMuteAndTakeoverSettersDispatchRuntimeActions() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        viewModel.isMediaAudioMuted = true
        XCTAssertTrue(viewModel.runtime.state.audio.isMediaMuted)
        XCTAssertEqual(viewModel.runtime.actionLog.last?.actionName, "operatorChangedMediaMute")
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .operatorFaderChanged)

        viewModel.isBGMAudioTakeoverActive = true
        XCTAssertTrue(viewModel.runtime.state.audio.isBGMTakeoverActive)
        XCTAssertEqual(viewModel.runtime.actionLog.last?.actionName, "operatorChangedBGMTakeover")
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .limiterChanged)
    }

    func testViewModelAudioSettersRouteSideEffectsThroughRuntimePort() {
        let audioRouting = AudioRoutingPortSpy()
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, audioRouting: audioRouting),
            environment: .productionAudioOwned()
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )

        viewModel.isMasterAudioMuted = true

        XCTAssertTrue(runtime.state.audio.isMasterMuted)
        XCTAssertEqual(audioRouting.reasons, [.operatorFaderChanged])
        XCTAssertEqual(audioRouting.masterMutedStates, [true])
        XCTAssertNil(viewModel.lastAudioRoutingTransition)
    }

    func testViewModelAudioPreferenceSettersRoutePersistenceThroughRuntimePort() {
        let suiteName = "LiveRuntimeAudioPanicBridgeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let persistence = PersistencePortSpy()
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, persistence: persistence),
            environment: .productionAudioOwned()
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults,
            runtime: runtime
        )

        viewModel.audioStrategy = .followSource
        viewModel.isSpeakerMode = true

        XCTAssertEqual(runtime.state.audio.strategy, .followSource)
        XCTAssertTrue(runtime.state.audio.isSpeakerMode)
        XCTAssertEqual(persistence.savedAudioStrategies, [.followSource])
        XCTAssertEqual(persistence.savedSpeakerModes, [true])
        XCTAssertEqual(persistence.saveCount, 0)
        XCTAssertNil(defaults.string(forKey: "audioStrategy"))
        XCTAssertNil(defaults.object(forKey: "speakerMode"))
    }

    func testViewModelPanicToggleDispatchesRuntimeActionAndAppliesRuntimeTransition() {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)

        viewModel.togglePanicMode()

        XCTAssertTrue(viewModel.runtime.state.panic.isActive)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSetPanic" })
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "supportEventRecorded" })
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .panicChanged)
    }

    func testRuntimeAudioRoutingPortAppliesReducedRuntimeState() throws {
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false)
        viewModel.runtime.updateEnvironment(LiveRuntimeEnvironment(bridgeMode: .fullRuntime))
        viewModel.liveAudioFadeDuration = 0
        let mediaURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        defer { try? FileManager.default.removeItem(at: mediaURL) }
        try Data("fixture".utf8).write(to: mediaURL)
        let item = ProgramItem(title: "Opening", subtitle: "VIDEO", sourceURL: mediaURL)
        viewModel.applyProgramQueueProjectionFromRuntime([item])
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())
        viewModel.avCoordinator.load(url: mediaURL)
        viewModel.avCoordinator.isPlaying = true
        viewModel.avCoordinator.volume = 1
        viewModel.resetLastAudioRoutingTransitionForTesting()

        viewModel.dispatchRuntimeFacadeAction(.operatorSetPanic(true))

        XCTAssertEqual(viewModel.runtime.state.audio.effectiveMedia, 0)
        XCTAssertEqual(viewModel.avCoordinator.volume, 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.reason, .panicChanged)
    }
}

private final class AudioRoutingPortSpy: AudioRoutingPort {
    private(set) var reasons: [AudioRoutingRuntimeChangeReason] = []
    private(set) var masterMutedStates: [Bool] = []

    func apply(reason: AudioRoutingRuntimeChangeReason, state: LiveRuntimeState) {
        reasons.append(reason)
        masterMutedStates.append(state.audio.isMasterMuted)
    }
}

private final class PersistencePortSpy: PersistencePort {
    private(set) var saveCount = 0
    private(set) var savedAudioStrategies: [AudioStrategy] = []
    private(set) var savedSpeakerModes: [Bool] = []

    func save() {
        saveCount += 1
    }

    func saveConsoleMode(_ mode: ConsoleMode) {}
    func saveThemeOverride(_ theme: ThemeOverride) {}
    func saveAudioStrategy(_ strategy: AudioStrategy) {
        savedAudioStrategies.append(strategy)
    }
    func saveSpeakerMode(_ isEnabled: Bool) {
        savedSpeakerModes.append(isEnabled)
    }
    func saveBGMPlayMode(_ playMode: BGMPlayMode) {}
    func saveAutoPlayNextVideoOnEnd(_ isEnabled: Bool) {}
    func saveAutoAdvanceAtScheduledTime(_ isEnabled: Bool) {}
    func saveShowAgendaTimeline(_ isEnabled: Bool) {}
    func saveCornerLogoPosition(_ position: CornerLogoPosition) {}
}
