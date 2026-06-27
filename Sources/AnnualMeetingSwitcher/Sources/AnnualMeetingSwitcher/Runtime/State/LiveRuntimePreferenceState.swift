import Foundation

struct LiveRuntimePreferenceState: Equatable {
    var themeOverride: ThemeOverride = .dark
    var activeWallpaperURL: URL?
    var companyDisplayName: String = ""
    var cornerLogoURL: URL?
    var isCornerLogoVisible = false
    var autoPlayNextVideoOnEnd = false
    var isAgendaTimeReminderEnabled = false
    var showAgendaTimeline = false
    var cornerLogoPosition: CornerLogoPosition = .topRight
}
