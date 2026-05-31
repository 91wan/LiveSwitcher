import Foundation

enum PPTStopReason: String, Equatable {
    case operatorDisabled
    case programChanged
    case failed
}

enum LiveRuntimeAction: Equatable {
    case operatorSelectedProgram(UUID)
    case operatorToggledMediaPlayback
    case operatorRestartedCurrentMedia
    case operatorSelectedAudioStrategy(AudioStrategy)
    case operatorChangedMasterVolume(Double)
    case operatorChangedMediaVolume(Double)
    case operatorChangedBGMVolume(Double)
    case operatorToggledSpeakerMode
    case operatorToggledPanic
    case operatorSelectedBGM(UUID)
    case operatorStoppedBGM
    case operatorSelectedNextBGM
    case operatorSelectedPreviousBGM
    case operatorToggledPPTMode(source: PPTModeToggleSource)
    case operatorToggledProjection

    case mediaLoaded(url: URL, generation: Int)
    case mediaPlaybackChanged(isPlaying: Bool, generation: Int)
    case mediaReachedEnd(generation: Int)
    case mediaSeekCompleted(time: Double, generation: Int)

    case bgmPrepared(id: UUID, generation: Int)
    case bgmPlaybackChanged(isPlaying: Bool, generation: Int)
    case bgmReachedEnd(generation: Int)
    case bgmFailed(reason: String, generation: Int)
    case bgmProgressUpdated(time: Double, duration: Double?, generation: Int)

    case panicFadeCompleted(generation: Int)
    case projectionExternalDisplayLost
    case projectionExternalDisplayAvailable
    case pptEventTapStarted
    case pptEventTapFailed(reason: String)
    case pptEventTapStopped(reason: PPTStopReason)

    case automationFailed(action: String, sanitizedMessage: String)
    case automationNoticeExpired(UUID)
    case automationNoticeDismissed

    case supportEventRecorded(LiveSupportEvent)
}

extension LiveRuntimeAction {
    var redactedName: String {
        switch self {
        case .operatorSelectedProgram: return "operatorSelectedProgram"
        case .operatorToggledMediaPlayback: return "operatorToggledMediaPlayback"
        case .operatorRestartedCurrentMedia: return "operatorRestartedCurrentMedia"
        case .operatorSelectedAudioStrategy: return "operatorSelectedAudioStrategy"
        case .operatorChangedMasterVolume: return "operatorChangedMasterVolume"
        case .operatorChangedMediaVolume: return "operatorChangedMediaVolume"
        case .operatorChangedBGMVolume: return "operatorChangedBGMVolume"
        case .operatorToggledSpeakerMode: return "operatorToggledSpeakerMode"
        case .operatorToggledPanic: return "operatorToggledPanic"
        case .operatorSelectedBGM: return "operatorSelectedBGM"
        case .operatorStoppedBGM: return "operatorStoppedBGM"
        case .operatorSelectedNextBGM: return "operatorSelectedNextBGM"
        case .operatorSelectedPreviousBGM: return "operatorSelectedPreviousBGM"
        case .operatorToggledPPTMode: return "operatorToggledPPTMode"
        case .operatorToggledProjection: return "operatorToggledProjection"
        case .mediaLoaded: return "mediaLoaded"
        case .mediaPlaybackChanged: return "mediaPlaybackChanged"
        case .mediaReachedEnd: return "mediaReachedEnd"
        case .mediaSeekCompleted: return "mediaSeekCompleted"
        case .bgmPrepared: return "bgmPrepared"
        case .bgmPlaybackChanged: return "bgmPlaybackChanged"
        case .bgmReachedEnd: return "bgmReachedEnd"
        case .bgmFailed: return "bgmFailed"
        case .bgmProgressUpdated: return "bgmProgressUpdated"
        case .panicFadeCompleted: return "panicFadeCompleted"
        case .projectionExternalDisplayLost: return "projectionExternalDisplayLost"
        case .projectionExternalDisplayAvailable: return "projectionExternalDisplayAvailable"
        case .pptEventTapStarted: return "pptEventTapStarted"
        case .pptEventTapFailed: return "pptEventTapFailed"
        case .pptEventTapStopped: return "pptEventTapStopped"
        case .automationFailed: return "automationFailed"
        case .automationNoticeExpired: return "automationNoticeExpired"
        case .automationNoticeDismissed: return "automationNoticeDismissed"
        case .supportEventRecorded: return "supportEventRecorded"
        }
    }
}
