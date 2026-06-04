import Foundation

enum PPTStopReason: String, Equatable {
    case operatorDisabled
    case programChanged
    case failed
}

enum ProjectionStartFailureReason: String, Equatable {
    case noTargetScreen
    case externalDisplayUnavailable
}

enum LiveRuntimeAction: Equatable {
    case operatorSelectedProgram(UUID)
    case operatorSelectedDetachedProgram(ProgramItem)
    case operatorToggledMediaPlayback
    case operatorRestartedCurrentMedia
    case operatorSeekedCurrentMediaToStart
    case operatorSeekedCurrentMediaToEnd
    case operatorStoppedCurrentMedia
    case operatorPausedMediaForPanic(generation: Int?)
    case operatorResumedMediaAfterPanic(generation: Int?)
    case operatorSelectedAudioStrategy(AudioStrategy)
    case operatorChangedMasterVolume(Double)
    case operatorChangedMediaVolume(Double)
    case operatorChangedBGMVolume(Double)
    case operatorChangedMasterMute(Bool)
    case operatorChangedMediaMute(Bool)
    case operatorChangedBGMMute(Bool)
    case operatorChangedBGMTakeover(Bool)
    case operatorToggledSpeakerMode
    case operatorSetSpeakerMode(Bool)
    case operatorToggledPanic
    case operatorSetPanic(Bool)
    case operatorSelectedBGM(UUID)
    case operatorSelectedBGMPlayMode(BGMPlayMode)
    case operatorSeekedBGMToBeginning
    case operatorSeekedBGMToProgress(Double)
    case operatorStoppedBGM
    case operatorSelectedNextBGM
    case operatorSelectedPreviousBGM
    case operatorPausedBGMForPanic(generation: Int?)
    case operatorResumedBGMAfterPanic(generation: Int?)
    case operatorToggledPPTMode(source: PPTModeToggleSource)
    case operatorToggledProjection
    case operatorSetConsoleMode(ConsoleMode)
    case operatorSetThemeOverride(ThemeOverride)
    case operatorSetActiveWallpaperURL(URL?)
    case operatorSetCornerLogoURL(URL?)
    case operatorSetAutoPlayNextVideoOnEnd(Bool)
    case operatorSetAutoAdvanceAtScheduledTime(Bool)
    case operatorSetShowAgendaTimeline(Bool)
    case operatorSetCornerLogoPosition(CornerLogoPosition)

    case mediaLoaded(url: URL, generation: Int)
    case mediaPlaybackChanged(isPlaying: Bool, generation: Int)
    case mediaReachedEnd(generation: Int)
    case mediaSeekCompleted(time: Double, generation: Int)
    case facadeCurrentProgramChanged(UUID?)
    case facadeAudioInputsChanged(AudioFacadeSnapshot)

    case bgmPrepared(id: UUID, generation: Int)
    case bgmPlaybackChanged(isPlaying: Bool, generation: Int)
    case bgmReachedEnd(generation: Int)
    case bgmFailed(reason: String, generation: Int)
    case bgmProgressUpdated(time: Double, duration: Double?, generation: Int)

    case panicFadeCompleted(generation: Int)
    case projectionStartFailed(reason: ProjectionStartFailureReason)
    case projectionExternalDisplayLost
    case projectionExternalDisplayAvailable
    case projectionExternalDisplayUnavailable
    case pptEventTapStarted
    case pptEventTapFailed(reason: String)
    case pptEventTapStopped(reason: PPTStopReason)

    case automationFailed(action: String, sanitizedMessage: String)
    case automationNoticeRequested(action: String)
    case automationNoticeExpired(UUID)
    case automationNoticeDismissed

    case supportEventRecorded(LiveSupportEvent)
}

extension LiveRuntimeAction {
    var redactedName: String {
        switch self {
        case .operatorSelectedProgram: return "operatorSelectedProgram"
        case .operatorSelectedDetachedProgram: return "operatorSelectedProgram"
        case .operatorToggledMediaPlayback: return "operatorToggledMediaPlayback"
        case .operatorRestartedCurrentMedia: return "operatorRestartedCurrentMedia"
        case .operatorSeekedCurrentMediaToStart: return "operatorSeekedCurrentMediaToStart"
        case .operatorSeekedCurrentMediaToEnd: return "operatorSeekedCurrentMediaToEnd"
        case .operatorStoppedCurrentMedia: return "operatorStoppedCurrentMedia"
        case .operatorPausedMediaForPanic: return "operatorPausedMediaForPanic"
        case .operatorResumedMediaAfterPanic: return "operatorResumedMediaAfterPanic"
        case .operatorSelectedAudioStrategy: return "operatorSelectedAudioStrategy"
        case .operatorChangedMasterVolume: return "operatorChangedMasterVolume"
        case .operatorChangedMediaVolume: return "operatorChangedMediaVolume"
        case .operatorChangedBGMVolume: return "operatorChangedBGMVolume"
        case .operatorChangedMasterMute: return "operatorChangedMasterMute"
        case .operatorChangedMediaMute: return "operatorChangedMediaMute"
        case .operatorChangedBGMMute: return "operatorChangedBGMMute"
        case .operatorChangedBGMTakeover: return "operatorChangedBGMTakeover"
        case .operatorToggledSpeakerMode: return "operatorToggledSpeakerMode"
        case .operatorSetSpeakerMode: return "operatorSetSpeakerMode"
        case .operatorToggledPanic: return "operatorToggledPanic"
        case .operatorSetPanic: return "operatorSetPanic"
        case .operatorSelectedBGM: return "operatorSelectedBGM"
        case .operatorSelectedBGMPlayMode: return "operatorSelectedBGMPlayMode"
        case .operatorSeekedBGMToBeginning: return "operatorSeekedBGMToBeginning"
        case .operatorSeekedBGMToProgress: return "operatorSeekedBGMToProgress"
        case .operatorStoppedBGM: return "operatorStoppedBGM"
        case .operatorSelectedNextBGM: return "operatorSelectedNextBGM"
        case .operatorSelectedPreviousBGM: return "operatorSelectedPreviousBGM"
        case .operatorPausedBGMForPanic: return "operatorPausedBGMForPanic"
        case .operatorResumedBGMAfterPanic: return "operatorResumedBGMAfterPanic"
        case .operatorToggledPPTMode: return "operatorToggledPPTMode"
        case .operatorToggledProjection: return "operatorToggledProjection"
        case .operatorSetConsoleMode: return "operatorSetConsoleMode"
        case .operatorSetThemeOverride: return "operatorSetThemeOverride"
        case .operatorSetActiveWallpaperURL: return "operatorSetActiveWallpaperURL"
        case .operatorSetCornerLogoURL: return "operatorSetCornerLogoURL"
        case .operatorSetAutoPlayNextVideoOnEnd: return "operatorSetAutoPlayNextVideoOnEnd"
        case .operatorSetAutoAdvanceAtScheduledTime: return "operatorSetAutoAdvanceAtScheduledTime"
        case .operatorSetShowAgendaTimeline: return "operatorSetShowAgendaTimeline"
        case .operatorSetCornerLogoPosition: return "operatorSetCornerLogoPosition"
        case .mediaLoaded: return "mediaLoaded"
        case .mediaPlaybackChanged: return "mediaPlaybackChanged"
        case .mediaReachedEnd: return "mediaReachedEnd"
        case .mediaSeekCompleted: return "mediaSeekCompleted"
        case .facadeCurrentProgramChanged: return "facadeCurrentProgramChanged"
        case .facadeAudioInputsChanged: return "facadeAudioInputsChanged"
        case .bgmPrepared: return "bgmPrepared"
        case .bgmPlaybackChanged: return "bgmPlaybackChanged"
        case .bgmReachedEnd: return "bgmReachedEnd"
        case .bgmFailed: return "bgmFailed"
        case .bgmProgressUpdated: return "bgmProgressUpdated"
        case .panicFadeCompleted: return "panicFadeCompleted"
        case .projectionStartFailed: return "projectionStartFailed"
        case .projectionExternalDisplayLost: return "projectionExternalDisplayLost"
        case .projectionExternalDisplayAvailable: return "projectionExternalDisplayAvailable"
        case .projectionExternalDisplayUnavailable: return "projectionExternalDisplayUnavailable"
        case .pptEventTapStarted: return "pptEventTapStarted"
        case .pptEventTapFailed: return "pptEventTapFailed"
        case .pptEventTapStopped: return "pptEventTapStopped"
        case .automationFailed: return "automationFailed"
        case .automationNoticeRequested: return "automationNoticeRequested"
        case .automationNoticeExpired: return "automationNoticeExpired"
        case .automationNoticeDismissed: return "automationNoticeDismissed"
        case .supportEventRecorded: return "supportEventRecorded"
        }
    }
}
