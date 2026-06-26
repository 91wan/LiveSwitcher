import Foundation

enum LiveModeActionKind: String, CaseIterable {
    case switchSource
    case takeNext
    case toggleCurrentMediaPlayback
    case returnCurrentMediaToStart
    case toggleProjection
    case togglePanic
    case toggleFadeToBlack
    case toggleSpeakerMode
    case togglePPTMode
    case bgmPlayPause
    case bgmPrevious
    case bgmNext
    case selectExistingBGM
    case triggerExistingOverlayPreset
    case selectExistingStandbyWallpaper

    var documentationLabel: String {
        switch self {
        case .switchSource:
            return "Switch source"
        case .takeNext:
            return "Take next"
        case .toggleCurrentMediaPlayback:
            return "Toggle main media playback"
        case .returnCurrentMediaToStart:
            return "Return current media to start"
        case .toggleProjection:
            return "Toggle projection"
        case .togglePanic:
            return "Toggle panic"
        case .toggleFadeToBlack:
            return "Toggle fade-to-black"
        case .toggleSpeakerMode:
            return "Toggle speaker mode"
        case .togglePPTMode:
            return "Toggle PPT mode"
        case .bgmPlayPause:
            return "Play or pause existing BGM"
        case .bgmPrevious:
            return "Select previous BGM"
        case .bgmNext:
            return "Select next BGM"
        case .selectExistingBGM:
            return "Select existing BGM"
        case .triggerExistingOverlayPreset:
            return "Trigger existing overlay presets"
        case .selectExistingStandbyWallpaper:
            return "Select existing standby wallpapers"
        }
    }
}

enum LiveModeConfigurationSurface: String, CaseIterable {
    case importProgramSource
    case editProgramQueue
    case editBGMLibrary
    case editOverlayPreset
    case editAutomationSettings
    case editAgendaReminder
    case editReleaseBuildDebugSettings

    var documentationLabel: String {
        switch self {
        case .importProgramSource:
            return "Importing or adding program sources"
        case .editProgramQueue:
            return "Editing the program queue structure"
        case .editBGMLibrary:
            return "Editing BGM library metadata"
        case .editOverlayPreset:
            return "Editing overlay preset definitions"
        case .editAutomationSettings:
            return "Editing automation settings"
        case .editAgendaReminder:
            return "Editing agenda reminder or auto-next preferences"
        case .editReleaseBuildDebugSettings:
            return "Editing release, build, debug, or developer settings"
        }
    }
}

enum LiveModeSimplicityPolicy {
    static let maxPrimaryActionCount = 12
    static let maxLiveRailCardCount = 4
    static let maxVisibleBGMRows = 5

    static let allowedActions: [LiveModeActionKind] = LiveModeActionKind.allCases

    static let primaryActions: [LiveModeActionKind] = [
        .switchSource,
        .takeNext,
        .toggleCurrentMediaPlayback,
        .returnCurrentMediaToStart,
        .toggleProjection,
        .togglePanic,
        .toggleFadeToBlack,
        .toggleSpeakerMode,
        .togglePPTMode,
        .bgmPlayPause,
        .bgmPrevious,
        .bgmNext
    ]

    static let forbiddenConfigurationSurfaces: [LiveModeConfigurationSurface] = LiveModeConfigurationSurface.allCases

    static func isAllowed(_ action: LiveModeActionKind) -> Bool {
        allowedActions.contains(action)
    }

    static func isForbidden(_ surface: LiveModeConfigurationSurface) -> Bool {
        forbiddenConfigurationSurfaces.contains(surface)
    }
}
