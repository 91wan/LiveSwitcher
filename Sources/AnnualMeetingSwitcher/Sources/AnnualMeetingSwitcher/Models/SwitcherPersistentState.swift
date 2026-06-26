import Foundation

struct SwitcherPersistentState: Equatable {
    var audioStrategy: AudioStrategy = .followProgram
    var isSpeakerMode: Bool = false
    var bgmPlayMode: BGMPlayMode = .loopAll

    var programItems: [ProgramItem] = []
    var bgmItems: [BGMItem] = []

    var backgroundWallpapers: [URL] = []
    var activeWallpaperURL: URL?
    var companyDisplayName: String = ""
    var cornerLogoURL: URL?
    var isCornerLogoVisible: Bool = false
    var cornerLogoPosition: CornerLogoPosition = .topRight

    var autoPlayNextVideoOnEnd: Bool = false
    var isAgendaTimeReminderEnabled: Bool = false
    var showAgendaTimeline: Bool = false
    var consoleMode: ConsoleMode = .setup
    var themeOverride: ThemeOverride = .dark

    var lowerThirdPresets: [LowerThirdPreset] = []
    var countdownPresets: [CountdownPreset] = []
    var tickerPresets: [TickerPreset] = []
}
