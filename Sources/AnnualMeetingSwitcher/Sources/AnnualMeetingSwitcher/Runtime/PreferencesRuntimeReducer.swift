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

    static func setCornerLogoURL(
        _ url: URL?,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        state.preferences.cornerLogoURL = url
        effects.append(.loadCornerLogoImage(url))
    }

    static func setAutoPlayNextVideoOnEnd(
        _ isEnabled: Bool,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        state.preferences.autoPlayNextVideoOnEnd = isEnabled
        effects.append(.saveAutoPlayNextVideoOnEnd(isEnabled))
    }

    static func setAutoAdvanceAtScheduledTime(
        _ isEnabled: Bool,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        state.preferences.autoAdvanceAtScheduledTime = isEnabled
        effects.append(.saveAutoAdvanceAtScheduledTime(isEnabled))
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
