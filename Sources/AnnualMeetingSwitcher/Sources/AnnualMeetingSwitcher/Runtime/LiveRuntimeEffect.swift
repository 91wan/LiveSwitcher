import Foundation

enum LiveRuntimeEffect: Equatable {
    case loadMedia(URL, generation: Int)
    case playMedia(generation: Int)
    case pauseMedia(generation: Int)
    case restartMedia(generation: Int)
    case seekMediaToStart(generation: Int)
    case seekMediaToEnd(generation: Int)
    case stopMedia(generation: Int)
    case setMediaVolume(Float, fade: TimeInterval, generation: Int)

    case prepareBGM(BGMItem, generation: Int)
    case playBGM(generation: Int)
    case pauseBGM(generation: Int)
    case stopBGM(fade: TimeInterval, generation: Int)
    case setBGMVolume(Float, fade: TimeInterval, generation: Int)
    case seekBGMToBeginning(generation: Int)
    case seekBGMToProgress(Double, generation: Int)
    case setBGMPlayMode(BGMPlayMode, generation: Int?)
    case startBGMTimer(generation: Int)
    case stopBGMTimer(generation: Int)

    case startProjection
    case stopProjection
    case showOutputWindow
    case hideOutputWindow

    case startPPTEventTap
    case stopPPTEventTap(reason: PPTStopReason)

    case executeProgramActivation(id: UUID, plan: ProgramActivationPlan)
    case runAppleScript(script: String, action: String)
    case showAutomationNotice(AutomationRuntimeNotice)
    case expireAutomationNotice(UUID, at: Date)
    case scanPresentationQuery(id: UUID)

    case applyAudioRouting(reason: AudioRoutingRuntimeChangeReason)
    case loadBackgroundImage(URL?)
    case loadCornerLogoImage(URL?)
    case saveConsoleMode(ConsoleMode)
    case saveThemeOverride(ThemeOverride)
    case saveAudioStrategy(AudioStrategy)
    case saveSpeakerMode(Bool)
    case saveBGMPlayMode(BGMPlayMode)
    case saveAutoPlayNextVideoOnEnd(Bool)
    case saveAutoAdvanceAtScheduledTime(Bool)
    case saveShowAgendaTimeline(Bool)
    case saveCornerLogoPosition(CornerLogoPosition)
    case savePersistentState
    case recordSupportEvent(LiveSupportEvent)
}
