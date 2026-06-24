import XCTest
@testable import LiveSwitcher

@MainActor
final class PersistentRuntimeHydrationTests: XCTestCase {
    func testPersistentHydrationRecalculatesEffectiveAudioForLoadedStrategy() {
        var state = baseRuntimeState()
        state.audio.strategy = .mixed
        state.audio.isSpeakerMode = false
        state.audio.effectiveMedia = 0.123
        state.audio.effectiveBGM = 0.987
        let runtime = runtimeStore(initialState: state, speakerModeDuckedRatio: 0.11)

        runtime.hydratePersistentOwnedState(SwitcherPersistentState(
            audioStrategy: .followSource,
            isSpeakerMode: false
        ))

        let expected = expectedAudioOutput(from: runtime.state, ratio: 0.11)
        XCTAssertEqual(runtime.state.audio.strategy, .followSource)
        XCTAssertEqual(runtime.state.audio.effectiveMedia, expected.media, accuracy: 0.0001)
        XCTAssertEqual(runtime.state.audio.effectiveBGM, expected.bgm, accuracy: 0.0001)
        XCTAssertNotEqual(runtime.state.audio.effectiveMedia, 0.123)
        XCTAssertNotEqual(runtime.state.audio.effectiveBGM, 0.987)
    }

    func testPersistentHydrationRecalculatesEffectiveAudioForLoadedSpeakerMode() {
        var state = baseRuntimeState()
        state.audio.strategy = .mixed
        state.audio.isSpeakerMode = false
        state.audio.effectiveMedia = 0.72
        state.audio.effectiveBGM = 0.48
        let runtime = runtimeStore(initialState: state, speakerModeDuckedRatio: 0.1)

        runtime.hydratePersistentOwnedState(SwitcherPersistentState(
            audioStrategy: .mixed,
            isSpeakerMode: true
        ))

        let expected = expectedAudioOutput(from: runtime.state, ratio: 0.1)
        XCTAssertTrue(runtime.state.audio.isSpeakerMode)
        XCTAssertEqual(runtime.state.audio.effectiveMedia, expected.media, accuracy: 0.0001)
        XCTAssertEqual(runtime.state.audio.effectiveBGM, expected.bgm, accuracy: 0.0001)
    }

    func testPersistentHydrationUsesFinalRoutingContextWhenRecalculatingAudio() {
        var state = baseRuntimeState()
        state.audio.routingContext = AudioRoutingContext(
            isCurrentProgramMediaSource: false,
            isMediaPlaying: false,
            isBGMPlaying: true,
            isPanicMode: false
        )
        state.audio.effectiveMedia = 0.44
        state.audio.effectiveBGM = 0.55
        let runtime = runtimeStore(initialState: state)

        runtime.hydratePersistentOwnedState(SwitcherPersistentState(
            audioStrategy: .followProgram,
            isSpeakerMode: false
        ))

        let expected = expectedAudioOutput(from: runtime.state)
        XCTAssertEqual(runtime.state.audio.routingContext, state.audio.routingContext)
        XCTAssertEqual(runtime.state.audio.effectiveMedia, expected.media, accuracy: 0.0001)
        XCTAssertEqual(runtime.state.audio.effectiveBGM, expected.bgm, accuracy: 0.0001)
    }

    func testPersistentHydrationPreservesAudioControlsWhileRecomputingDerivedOutputs() {
        var state = baseRuntimeState()
        state.audio.masterVolume = 0.63
        state.audio.mediaVolume = 0.74
        state.audio.bgmVolume = 0.85
        state.audio.isMasterMuted = false
        state.audio.isMediaMuted = true
        state.audio.isBGMMuted = false
        state.audio.isBGMTakeoverActive = true
        let runtime = runtimeStore(initialState: state)

        runtime.hydratePersistentOwnedState(SwitcherPersistentState(
            audioStrategy: .bgmOnly,
            isSpeakerMode: true
        ))

        XCTAssertEqual(runtime.state.audio.masterVolume, 0.63)
        XCTAssertEqual(runtime.state.audio.mediaVolume, 0.74)
        XCTAssertEqual(runtime.state.audio.bgmVolume, 0.85)
        XCTAssertFalse(runtime.state.audio.isMasterMuted)
        XCTAssertTrue(runtime.state.audio.isMediaMuted)
        XCTAssertFalse(runtime.state.audio.isBGMMuted)
        XCTAssertTrue(runtime.state.audio.isBGMTakeoverActive)
        let expected = expectedAudioOutput(from: runtime.state)
        XCTAssertEqual(runtime.state.audio.effectiveMedia, expected.media, accuracy: 0.0001)
        XCTAssertEqual(runtime.state.audio.effectiveBGM, expected.bgm, accuracy: 0.0001)
    }

    func testPersistentHydrationUpdatesOwnedBGMModeAndPreferencesWithoutEffects() {
        let runtime = runtimeStore(initialState: baseRuntimeState())

        runtime.hydratePersistentOwnedState(SwitcherPersistentState(
            bgmPlayMode: .loopOne,
            activeWallpaperURL: URL(fileURLWithPath: "/tmp/hydrated-wallpaper.png"),
            cornerLogoURL: URL(fileURLWithPath: "/tmp/hydrated-logo.png"),
            cornerLogoPosition: .bottomRight,
            autoPlayNextVideoOnEnd: true,
            autoAdvanceAtScheduledTime: true,
            showAgendaTimeline: true,
            consoleMode: .live,
            themeOverride: .light
        ))

        XCTAssertEqual(runtime.state.bgm.playMode, .loopOne)
        XCTAssertEqual(runtime.state.mode, .live)
        XCTAssertEqual(runtime.state.preferences.themeOverride, .light)
        XCTAssertEqual(runtime.state.preferences.activeWallpaperURL, URL(fileURLWithPath: "/tmp/hydrated-wallpaper.png"))
        XCTAssertEqual(runtime.state.preferences.cornerLogoURL, URL(fileURLWithPath: "/tmp/hydrated-logo.png"))
        XCTAssertEqual(runtime.state.preferences.cornerLogoPosition, .bottomRight)
        XCTAssertTrue(runtime.state.preferences.autoPlayNextVideoOnEnd)
        XCTAssertTrue(runtime.state.preferences.autoAdvanceAtScheduledTime)
        XCTAssertTrue(runtime.state.preferences.showAgendaTimeline)
        XCTAssertTrue(runtime.actionLog.isEmpty)
        XCTAssertTrue(runtime.recordedEffects.isEmpty)
    }

    func testPersistentHydrationNoopsWhenDomainsAreNotOwned() {
        var state = baseRuntimeState()
        state.audio.strategy = .mixed
        state.audio.isSpeakerMode = false
        state.bgm.playMode = .loopAll
        state.mode = .setup
        state.preferences.themeOverride = .dark
        state.audio.effectiveMedia = 0.123
        state.audio.effectiveBGM = 0.456
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: .recordingOnlyForTests()
        )

        runtime.hydratePersistentOwnedState(SwitcherPersistentState(
            audioStrategy: .followSource,
            isSpeakerMode: true,
            bgmPlayMode: .loopOne,
            consoleMode: .live,
            themeOverride: .light
        ))

        XCTAssertEqual(runtime.state, state)
        XCTAssertTrue(runtime.actionLog.isEmpty)
        XCTAssertTrue(runtime.recordedEffects.isEmpty)
    }

    func testPersistentHydrationPreservesActionLogAndBridgeMode() {
        let runtime = runtimeStore(initialState: baseRuntimeState())
        runtime.dispatch(.operatorSetConsoleMode(.live))
        let actionLog = runtime.actionLog
        let bridgeMode = runtime.bridgeMode

        runtime.hydratePersistentOwnedState(SwitcherPersistentState(
            audioStrategy: .followSource,
            isSpeakerMode: true,
            consoleMode: .setup
        ))

        XCTAssertEqual(runtime.actionLog, actionLog)
        XCTAssertEqual(runtime.bridgeMode, bridgeMode)
    }

    func testStoreSourceDoesNotAddGenericPersistentMutationAPI() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeStore.swift")

        XCTAssertTrue(source.contains("func hydratePersistentOwnedState(_ persistentState: SwitcherPersistentState)"))
        XCTAssertFalse(source.contains("mutateState("))
        XCTAssertFalse(source.contains("setState("))
        XCTAssertFalse(source.contains("replaceStateForPersistentLoad"))
    }

    private func runtimeStore(
        initialState: LiveRuntimeState,
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio
    ) -> LiveRuntimeStore {
        LiveRuntimeStore(
            initialState: initialState,
            effectRunner: .recording(),
            environment: .fullRuntimeForTests(speakerModeDuckedRatio: speakerModeDuckedRatio)
        )
    }

    private func baseRuntimeState() -> LiveRuntimeState {
        let video = ProgramItem(
            title: "Opening",
            subtitle: "MEDIA",
            sourceURL: URL(fileURLWithPath: "/tmp/opening.mp4")
        )
        let bgm = BGMItem(
            title: "Walk In",
            url: URL(fileURLWithPath: "/tmp/walk-in.mp3"),
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
        state.audio.routingContext = AudioRoutingContext(
            isCurrentProgramMediaSource: true,
            isMediaPlaying: true,
            isBGMPlaying: true,
            isPanicMode: false
        )
        return state
    }

    private func expectedAudioOutput(
        from state: LiveRuntimeState,
        ratio: Float = AudioRoutingDefaults.speakerModeDuckedRatio
    ) -> AudioRoutingOutput {
        let context = state.audio.routingContext
        return AudioRoutingEngine.output(for: AudioRoutingInput(
            masterVolume: state.audio.masterVolume,
            mediaVolume: state.audio.mediaVolume,
            bgmVolume: state.audio.bgmVolume,
            audioStrategy: state.audio.strategy,
            isCurrentProgramMediaSource: context.isCurrentProgramMediaSource,
            isMediaPlaying: context.isMediaPlaying,
            isBGMAudioTakeoverActive: state.audio.isBGMTakeoverActive,
            isSpeakerMode: state.audio.isSpeakerMode,
            isPanicMode: context.isPanicMode,
            isMasterMuted: state.audio.isMasterMuted,
            isMediaMuted: state.audio.isMediaMuted,
            isBGMMuted: state.audio.isBGMMuted,
            speakerModeDuckedRatio: ratio
        ))
    }
}
