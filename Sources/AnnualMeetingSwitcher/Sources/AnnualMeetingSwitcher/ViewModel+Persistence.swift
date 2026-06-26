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
            companyDisplayName: preferences.companyDisplayName,
            cornerLogoURL: preferences.cornerLogoURL,
            isCornerLogoVisible: preferences.isCornerLogoVisible,
            cornerLogoPosition: preferences.cornerLogoPosition,
            autoPlayNextVideoOnEnd: preferences.autoPlayNextVideoOnEnd,
            isAgendaTimeReminderEnabled: preferences.isAgendaTimeReminderEnabled,
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
        syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)
        runtime.hydratePersistentOwnedState(state)
    }

    private func projectPersistentStateToFacadeDuringLoad(
        _ state: SwitcherPersistentState
    ) {
        withRuntimeFacadeDispatchSuppressed {
            audioStrategy = state.audioStrategy
            isSpeakerMode = state.isSpeakerMode
            bgmPlayMode = state.bgmPlayMode
            activeWallpaperURL = state.activeWallpaperURL
            companyDisplayName = state.companyDisplayName
            cornerLogoURL = state.cornerLogoURL
            isCornerLogoVisible = state.isCornerLogoVisible
            cornerLogoPosition = state.cornerLogoPosition
            autoPlayNextVideoOnEnd = state.autoPlayNextVideoOnEnd
            isAgendaTimeReminderEnabled = state.isAgendaTimeReminderEnabled
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
            companyDisplayName: companyDisplayName,
            cornerLogoURL: cornerLogoURL,
            isCornerLogoVisible: isCornerLogoVisible,
            autoPlayNextVideoOnEnd: autoPlayNextVideoOnEnd,
            isAgendaTimeReminderEnabled: isAgendaTimeReminderEnabled,
            showAgendaTimeline: showAgendaTimeline,
            cornerLogoPosition: cornerLogoPosition
        )
    }

    func persistConsoleModeFromRuntime(_ mode: ConsoleMode) {
        persistenceStore.saveConsoleMode(mode)
    }

    func persistThemeOverrideFromRuntime(_ theme: ThemeOverride) {
        persistenceStore.saveThemeOverride(theme)
    }

    func persistCompanyDisplayNameFromRuntime(_ displayName: String) {
        persistenceStore.saveCompanyDisplayName(displayName)
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

    func persistAgendaTimeReminderEnabledFromRuntime(_ isEnabled: Bool) {
        persistenceStore.saveAgendaTimeReminderEnabled(isEnabled)
    }

    func persistShowAgendaTimelineFromRuntime(_ isEnabled: Bool) {
        persistenceStore.saveShowAgendaTimeline(isEnabled)
    }

    func persistCornerLogoVisibleFromRuntime(_ isVisible: Bool) {
        persistenceStore.saveCornerLogoVisible(isVisible)
    }

    func persistCornerLogoPositionFromRuntime(_ position: CornerLogoPosition) {
        persistenceStore.saveCornerLogoPosition(position)
    }
}
