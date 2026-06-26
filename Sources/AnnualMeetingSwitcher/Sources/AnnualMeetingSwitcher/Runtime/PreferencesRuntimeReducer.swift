import Foundation

enum PreferencesRuntimeReducer {
    static func setConsoleMode(
        _ mode: ConsoleMode,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        state.mode = mode
        effects.append(.saveConsoleMode(mode))
    }

    static func setThemeOverride(
        _ theme: ThemeOverride,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        state.preferences.themeOverride = theme
        effects.append(.saveThemeOverride(theme))
    }

    static func setActiveWallpaperURL(
        _ url: URL?,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        state.preferences.activeWallpaperURL = url
        effects.append(.loadBackgroundImage(url))
    }

    static func setCompanyDisplayName(
        _ displayName: String,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        let normalized = BrandingDisplayNamePolicy.normalizedDisplayName(from: displayName)
        guard BrandingDisplayNamePolicy.validationMessage(for: normalized) == nil else { return }
        state.preferences.companyDisplayName = normalized
        effects.append(.saveCompanyDisplayName(normalized))
    }

    static func setCornerLogoURL(
        _ url: URL?,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        let hadLogo = state.preferences.cornerLogoURL != nil
        state.preferences.cornerLogoURL = url
        effects.append(.loadCornerLogoImage(url))
        if url == nil {
            state.preferences.isCornerLogoVisible = false
            effects.append(.saveCornerLogoVisible(false))
        } else if !hadLogo {
            state.preferences.isCornerLogoVisible = true
            effects.append(.saveCornerLogoVisible(true))
        }
    }

    static func setCornerLogoVisible(
        _ isVisible: Bool,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        state.preferences.isCornerLogoVisible = isVisible && state.preferences.cornerLogoURL != nil
        effects.append(.saveCornerLogoVisible(state.preferences.isCornerLogoVisible))
    }

    static func setAutoPlayNextVideoOnEnd(
        _ isEnabled: Bool,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        state.preferences.autoPlayNextVideoOnEnd = isEnabled
        effects.append(.saveAutoPlayNextVideoOnEnd(isEnabled))
    }

    static func setAgendaTimeReminderEnabled(
        _ isEnabled: Bool,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        state.preferences.isAgendaTimeReminderEnabled = isEnabled
        effects.append(.saveAgendaTimeReminderEnabled(isEnabled))
    }

    static func setShowAgendaTimeline(
        _ isEnabled: Bool,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        state.preferences.showAgendaTimeline = isEnabled
        effects.append(.saveShowAgendaTimeline(isEnabled))
    }

    static func setCornerLogoPosition(
        _ position: CornerLogoPosition,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        state.preferences.cornerLogoPosition = position
        effects.append(.saveCornerLogoPosition(position))
    }
}
