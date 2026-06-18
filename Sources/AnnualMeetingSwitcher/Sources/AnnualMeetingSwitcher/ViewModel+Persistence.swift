import Foundation

extension SwitcherViewModel {
    func saveData() {
        persistenceStore.save(makePersistentStateSnapshot())
        testHooks.saveDataDidRun?()
    }

    func loadData() {
        let result = persistenceStore.load()
        applyPersistentState(result.state)
        persistenceStore.repairAudioStrategyPersistenceIfNeeded(result.state.audioStrategy)
        persistenceStore.applyRepairs(result.repairs)
        for event in result.supportEvents {
            recordSupportEvent(kind: event.kind, detail: event.detail, timestamp: event.timestamp)
        }
    }

    private var persistenceStore: SwitcherPersistenceStore {
        SwitcherPersistenceStore(userDefaults: persistenceFacadeUserDefaults)
    }

    func makePersistentStateSnapshot() -> SwitcherPersistentState {
        let preferences = runtimeBackedPreferencesForPersistentSnapshot
        return SwitcherPersistentState(
            audioStrategy: runtimeBackedAudioStrategyForPersistentSnapshot,
            isSpeakerMode: runtimeBackedSpeakerModeForPersistentSnapshot,
            bgmPlayMode: runtimeBackedBGMPlayModeForPersistentSnapshot,
            programItems: runtimeBackedProgramItemsForPersistentSnapshot,
            bgmItems: bgmItems,
            backgroundWallpapers: backgroundWallpapers,
            activeWallpaperURL: preferences.activeWallpaperURL,
            cornerLogoURL: preferences.cornerLogoURL,
            cornerLogoPosition: preferences.cornerLogoPosition,
            autoPlayNextVideoOnEnd: preferences.autoPlayNextVideoOnEnd,
            autoAdvanceAtScheduledTime: preferences.autoAdvanceAtScheduledTime,
            showAgendaTimeline: preferences.showAgendaTimeline,
            consoleMode: runtimeBackedConsoleModeForPersistentSnapshot,
            themeOverride: preferences.themeOverride,
            lowerThirdPresets: lowerThirdPresets,
            countdownPresets: countdownPresets,
            tickerPresets: tickerPresets
        )
    }

    func applyPersistentState(_ state: SwitcherPersistentState) {
        let bridgeMode = runtime.bridgeMode
        projectPersistentStateToFacadeDuringLoad(state)
        if bridgeMode.owns(.programQueue) {
            dispatchRuntimeFacadeAction(.facadeLoadedProgramQueue(state.programItems))
        } else {
            applyProgramQueueProjectionFromRuntime(state.programItems)
        }
        bgmItems = state.bgmItems
        backgroundWallpapers = state.backgroundWallpapers
        lowerThirdPresets = state.lowerThirdPresets
        countdownPresets = state.countdownPresets
        tickerPresets = state.tickerPresets
        loadPersistentImageAssetsAfterFacadeProjection()
        applyPersistentStateToRuntimeIfOwned(state, bridgeMode: bridgeMode)
        syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)
    }

    private func projectPersistentStateToFacadeDuringLoad(
        _ state: SwitcherPersistentState
    ) {
        withRuntimeFacadeDispatchSuppressed {
            audioStrategy = state.audioStrategy
            isSpeakerMode = state.isSpeakerMode
            bgmPlayMode = state.bgmPlayMode
            activeWallpaperURL = state.activeWallpaperURL
            cornerLogoURL = state.cornerLogoURL
            cornerLogoPosition = state.cornerLogoPosition
            autoPlayNextVideoOnEnd = state.autoPlayNextVideoOnEnd
            autoAdvanceAtScheduledTime = state.autoAdvanceAtScheduledTime
            showAgendaTimeline = state.showAgendaTimeline
            consoleMode = state.consoleMode
            themeOverride = state.themeOverride
        }
    }

    private func loadPersistentImageAssetsAfterFacadeProjection() {
        loadBackgroundImage(from: activeWallpaperURL)
        loadCornerLogoImage(from: cornerLogoURL)
    }

    private var runtimeBackedAudioStrategyForPersistentSnapshot: AudioStrategy {
        runtime.bridgeMode.owns(.audio) ? runtime.state.audio.strategy : audioStrategy
    }

    private var runtimeBackedSpeakerModeForPersistentSnapshot: Bool {
        runtime.bridgeMode.owns(.audio) ? runtime.state.audio.isSpeakerMode : isSpeakerMode
    }

    private var runtimeBackedBGMPlayModeForPersistentSnapshot: BGMPlayMode {
        runtime.bridgeMode.owns(.bgm) ? runtime.state.bgm.playMode : bgmPlayMode
    }

    private var runtimeBackedProgramItemsForPersistentSnapshot: [ProgramItem] {
        runtime.bridgeMode.owns(.programQueue) ? runtime.state.program.items : programItems
    }

    private var runtimeBackedConsoleModeForPersistentSnapshot: ConsoleMode {
        runtime.bridgeMode.owns(.persistence) ? runtime.state.mode : consoleMode
    }

    private var runtimeBackedPreferencesForPersistentSnapshot: LiveRuntimePreferenceState {
        runtime.bridgeMode.owns(.persistence) ? runtime.state.preferences : LiveRuntimePreferenceState(
            themeOverride: themeOverride,
            activeWallpaperURL: activeWallpaperURL,
            cornerLogoURL: cornerLogoURL,
            autoPlayNextVideoOnEnd: autoPlayNextVideoOnEnd,
            autoAdvanceAtScheduledTime: autoAdvanceAtScheduledTime,
            showAgendaTimeline: showAgendaTimeline,
            cornerLogoPosition: cornerLogoPosition
        )
    }

    private func applyPersistentStateToRuntimeIfOwned(
        _ state: SwitcherPersistentState,
        bridgeMode: LiveRuntimeBridgeMode
    ) {
        var runtimeState = runtime.state
        var shouldReplaceRuntimeState = false

        if bridgeMode.owns(.audio) {
            runtimeState.audio.strategy = state.audioStrategy
            runtimeState.audio.isSpeakerMode = state.isSpeakerMode
            shouldReplaceRuntimeState = true
        }

        if bridgeMode.owns(.bgm) {
            runtimeState.bgm.playMode = state.bgmPlayMode
            shouldReplaceRuntimeState = true
        }

        if bridgeMode.owns(.persistence) {
            runtimeState.mode = state.consoleMode
            runtimeState.preferences = LiveRuntimePreferenceState(
                themeOverride: state.themeOverride,
                activeWallpaperURL: state.activeWallpaperURL,
                cornerLogoURL: state.cornerLogoURL,
                autoPlayNextVideoOnEnd: state.autoPlayNextVideoOnEnd,
                autoAdvanceAtScheduledTime: state.autoAdvanceAtScheduledTime,
                showAgendaTimeline: state.showAgendaTimeline,
                cornerLogoPosition: state.cornerLogoPosition
            )
            shouldReplaceRuntimeState = true
        }

        guard shouldReplaceRuntimeState else { return }

        runtime.replaceStateForFacadeSync(runtimeState, clearActionLog: false)
    }

    func persistConsoleModeFromRuntime(_ mode: ConsoleMode) {
        persistenceStore.saveConsoleMode(mode)
    }

    func persistThemeOverrideFromRuntime(_ theme: ThemeOverride) {
        persistenceStore.saveThemeOverride(theme)
    }

    func persistAudioStrategyFromRuntime(_ strategy: AudioStrategy) {
        persistenceStore.saveAudioStrategy(strategy)
    }

    func persistSpeakerModeFromRuntime(_ isEnabled: Bool) {
        persistenceStore.saveSpeakerMode(isEnabled)
    }

    func persistBGMPlayModeFromRuntime(_ playMode: BGMPlayMode) {
        persistenceStore.saveBGMPlayMode(playMode)
    }

    func persistAutoPlayNextVideoOnEndFromRuntime(_ isEnabled: Bool) {
        persistenceStore.saveAutoPlayNextVideoOnEnd(isEnabled)
    }

    func persistAutoAdvanceAtScheduledTimeFromRuntime(_ isEnabled: Bool) {
        persistenceStore.saveAutoAdvanceAtScheduledTime(isEnabled)
    }

    func persistShowAgendaTimelineFromRuntime(_ isEnabled: Bool) {
        persistenceStore.saveShowAgendaTimeline(isEnabled)
    }

    func persistCornerLogoPositionFromRuntime(_ position: CornerLogoPosition) {
        persistenceStore.saveCornerLogoPosition(position)
    }
}
