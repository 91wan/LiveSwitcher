import Foundation

extension SwitcherViewModel {
    func saveData() {
        persistenceStore.save(makePersistentStateSnapshot())
        testHooks.saveDataDidRun?()
    }

    func loadData() {
        let result = persistenceStore.load()
        applyPersistentState(result.state)
        persistenceStore.applyRepairs(result.repairs)
        for event in result.supportEvents {
            recordSupportEvent(kind: event.kind, detail: event.detail, timestamp: event.timestamp)
        }
    }

    private var persistenceStore: SwitcherPersistenceStore {
        SwitcherPersistenceStore(userDefaults: persistenceFacadeUserDefaults)
    }

    func makePersistentStateSnapshot() -> SwitcherPersistentState {
        SwitcherPersistentState(
            audioStrategy: audioStrategy,
            isSpeakerMode: isSpeakerMode,
            bgmPlayMode: bgmPlayMode,
            programItems: programItems,
            bgmItems: bgmItems,
            backgroundWallpapers: backgroundWallpapers,
            activeWallpaperURL: activeWallpaperURL,
            cornerLogoURL: cornerLogoURL,
            cornerLogoPosition: cornerLogoPosition,
            autoPlayNextVideoOnEnd: autoPlayNextVideoOnEnd,
            autoAdvanceAtScheduledTime: autoAdvanceAtScheduledTime,
            showAgendaTimeline: showAgendaTimeline,
            consoleMode: consoleMode,
            themeOverride: themeOverride,
            lowerThirdPresets: lowerThirdPresets,
            countdownPresets: countdownPresets,
            tickerPresets: tickerPresets
        )
    }

    func applyPersistentState(_ state: SwitcherPersistentState) {
        audioStrategy = state.audioStrategy
        isSpeakerMode = state.isSpeakerMode
        bgmPlayMode = state.bgmPlayMode
        if runtime.bridgeMode.owns(.programQueue) {
            dispatchRuntimeFacadeAction(.facadeLoadedProgramQueue(state.programItems))
        } else {
            programItems = state.programItems
        }
        bgmItems = state.bgmItems
        backgroundWallpapers = state.backgroundWallpapers
        activeWallpaperURL = state.activeWallpaperURL
        cornerLogoURL = state.cornerLogoURL
        cornerLogoPosition = state.cornerLogoPosition
        autoPlayNextVideoOnEnd = state.autoPlayNextVideoOnEnd
        autoAdvanceAtScheduledTime = state.autoAdvanceAtScheduledTime
        showAgendaTimeline = state.showAgendaTimeline
        consoleMode = state.consoleMode
        themeOverride = state.themeOverride
        lowerThirdPresets = state.lowerThirdPresets
        countdownPresets = state.countdownPresets
        tickerPresets = state.tickerPresets
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
