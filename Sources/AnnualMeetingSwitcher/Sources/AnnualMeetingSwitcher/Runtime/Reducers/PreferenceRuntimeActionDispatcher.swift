enum PreferenceRuntimeActionDispatcher {
    static func dispatch(
        action: LiveRuntimeAction,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        environment: LiveRuntimeEnvironment
    ) -> Bool {
        let bridgeMode = environment.bridgeMode

        switch action {
        case .operatorSetConsoleMode(let mode):
            guard LiveRuntimeReducer.isRuntimeOwned(.persistence, in: bridgeMode) else { return true }
            PreferencesRuntimeReducer.setConsoleMode(mode, state: &state, effects: &effects)

        case .operatorSetThemeOverride(let theme):
            guard LiveRuntimeReducer.isRuntimeOwned(.persistence, in: bridgeMode) else { return true }
            PreferencesRuntimeReducer.setThemeOverride(theme, state: &state, effects: &effects)

        case .operatorSetActiveWallpaperURL(let url):
            guard LiveRuntimeReducer.isRuntimeOwned(.persistence, in: bridgeMode),
                  LiveRuntimeReducer.isRuntimeOwned(.imageAssets, in: bridgeMode)
            else { return true }
            PreferencesRuntimeReducer.setActiveWallpaperURL(url, state: &state, effects: &effects)

        case .operatorSetCompanyDisplayName(let displayName):
            guard LiveRuntimeReducer.isRuntimeOwned(.persistence, in: bridgeMode) else { return true }
            PreferencesRuntimeReducer.setCompanyDisplayName(displayName, state: &state, effects: &effects)

        case .operatorSetCornerLogoURL(let url):
            guard LiveRuntimeReducer.isRuntimeOwned(.persistence, in: bridgeMode),
                  LiveRuntimeReducer.isRuntimeOwned(.imageAssets, in: bridgeMode)
            else { return true }
            PreferencesRuntimeReducer.setCornerLogoURL(url, state: &state, effects: &effects)

        case .operatorSetCornerLogoVisible(let isVisible):
            guard LiveRuntimeReducer.isRuntimeOwned(.persistence, in: bridgeMode) else { return true }
            PreferencesRuntimeReducer.setCornerLogoVisible(isVisible, state: &state, effects: &effects)

        case .operatorSetAutoPlayNextVideoOnEnd(let isEnabled):
            guard LiveRuntimeReducer.isRuntimeOwned(.persistence, in: bridgeMode) else { return true }
            PreferencesRuntimeReducer.setAutoPlayNextVideoOnEnd(isEnabled, state: &state, effects: &effects)

        case .operatorSetAgendaTimeReminderEnabled(let isEnabled):
            guard LiveRuntimeReducer.isRuntimeOwned(.persistence, in: bridgeMode) else { return true }
            PreferencesRuntimeReducer.setAgendaTimeReminderEnabled(isEnabled, state: &state, effects: &effects)

        case .operatorSetShowAgendaTimeline(let isEnabled):
            guard LiveRuntimeReducer.isRuntimeOwned(.persistence, in: bridgeMode) else { return true }
            PreferencesRuntimeReducer.setShowAgendaTimeline(isEnabled, state: &state, effects: &effects)

        case .operatorSetCornerLogoPosition(let position):
            guard LiveRuntimeReducer.isRuntimeOwned(.persistence, in: bridgeMode) else { return true }
            PreferencesRuntimeReducer.setCornerLogoPosition(position, state: &state, effects: &effects)

        default:
            return false
        }

        return true
    }
}
