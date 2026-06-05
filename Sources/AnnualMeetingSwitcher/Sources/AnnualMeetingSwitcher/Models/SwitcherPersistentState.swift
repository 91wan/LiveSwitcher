import Foundation

struct SwitcherPersistentState: Equatable {
    var audioStrategy: AudioStrategy = .mixed
    var isSpeakerMode: Bool = false
    var bgmPlayMode: BGMPlayMode = .loopAll

    var programItems: [ProgramItem] = []
    var bgmItems: [BGMItem] = []

    var backgroundWallpapers: [URL] = []
    var activeWallpaperURL: URL?
    var cornerLogoURL: URL?
    var cornerLogoPosition: CornerLogoPosition = .topRight

    var autoPlayNextVideoOnEnd: Bool = false
    var autoAdvanceAtScheduledTime: Bool = false
    var showAgendaTimeline: Bool = false
    var consoleMode: ConsoleMode = .setup
    var themeOverride: ThemeOverride = .dark

    var lowerThirdPresets: [LowerThirdPreset] = []
    var countdownPresets: [CountdownPreset] = []
    var tickerPresets: [TickerPreset] = []
}
