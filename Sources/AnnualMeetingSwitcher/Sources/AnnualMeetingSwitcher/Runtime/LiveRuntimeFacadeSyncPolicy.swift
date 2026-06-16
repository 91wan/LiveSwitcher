import Foundation

struct LiveRuntimeFacadeSyncOptions: Equatable {
    var dispatchAudioInputsChanged: Bool
    var syncBGM: Bool
    var syncProjection: Bool
    var syncPPT: Bool
    var syncAutomationNotice: Bool
    var syncSupport: Bool
    var syncProgramQueue: Bool
    var syncCurrentProgram: Bool
    var syncPanic: Bool
}

enum LiveRuntimeFacadeSyncPolicy {
    static func options(for action: LiveRuntimeAction) -> LiveRuntimeFacadeSyncOptions {
        LiveRuntimeFacadeSyncOptions(
            dispatchAudioInputsChanged: shouldDispatchAudioInputsBeforeRuntimeAction(action),
            syncBGM: shouldSyncBGMFacadeAfterRuntimeAction(action),
            syncProjection: shouldSyncProjectionFacadeAfterRuntimeAction(action),
            syncPPT: shouldSyncPPTFacadeAfterRuntimeAction(action),
            syncAutomationNotice: shouldSyncAutomationNoticeFacadeAfterRuntimeAction(action),
            syncSupport: shouldSyncSupportFacadeAfterRuntimeAction(action),
            syncProgramQueue: shouldSyncProgramQueueFacadeAfterRuntimeAction(action),
            syncCurrentProgram: shouldSyncCurrentProgramFacadeAfterRuntimeAction(action),
            syncPanic: shouldSyncPanicFacadeAfterRuntimeAction(action)
        )
    }

    private static func shouldDispatchAudioInputsBeforeRuntimeAction(_ action: LiveRuntimeAction) -> Bool {
        switch action {
        case .operatorClearedCurrentProgram,
             .operatorSetConsoleMode,
             .operatorSetThemeOverride,
             .operatorSetActiveWallpaperURL,
             .operatorSetCornerLogoURL,
             .operatorSetAutoPlayNextVideoOnEnd,
             .operatorSetAutoAdvanceAtScheduledTime,
             .operatorSetShowAgendaTimeline,
             .operatorSetCornerLogoPosition,
             .mediaLoaded,
             .operatorSelectedAudioStrategy,
             .operatorChangedMasterVolume,
             .operatorChangedMediaVolume,
             .operatorChangedBGMVolume,
             .operatorChangedMasterMute,
             .operatorChangedMediaMute,
             .operatorChangedBGMMute,
             .operatorChangedBGMTakeover,
             .operatorToggledSpeakerMode,
             .operatorSetSpeakerMode,
             .mediaPlaybackChanged,
             .mediaReachedEnd,
             .mediaSeekCompleted,
             .facadeCurrentProgramChanged,
             .bgmPrepared,
             .bgmPlaybackChanged,
             .bgmReachedEnd,
             .bgmFailed,
             .bgmProgressUpdated,
             .operatorPausedBGMForPanic,
             .operatorResumedBGMAfterPanic,
             .operatorSetPanic,
             .operatorToggledPanic,
             .panicBGMPauseDelayElapsed,
             .operatorRequestedPresentationQuery,
             .presentationQueryCompleted,
             .presentationQueryFailed,
             .presentationQueryResultConsumed,
             .automationFailed,
             .automationNoticeRequested,
             .automationNoticeExpired,
             .automationNoticeDismissed,
             .supportEventRecorded,
             .operatorRequestedProgramActivation,
             .programActivationCompleted,
             .operatorAddedProgramItems,
             .operatorRemovedProgramItem,
             .operatorMovedProgramItems,
             .operatorUpdatedProgramItemSchedule,
             .operatorAddedAgendaMarker,
             .facadeLoadedProgramQueue,
             .facadeAudioInputsChanged:
            return false
        default:
            return true
        }
    }

    private static func shouldSyncBGMFacadeAfterRuntimeAction(_ action: LiveRuntimeAction) -> Bool {
        switch action {
        case .operatorSelectedBGM,
             .operatorStoppedBGM,
             .operatorSelectedNextBGM,
             .operatorSelectedPreviousBGM,
             .operatorPausedBGMForPanic,
             .operatorResumedBGMAfterPanic,
             .operatorSetPanic,
             .operatorToggledPanic,
             .panicBGMPauseDelayElapsed,
             .operatorSelectedBGMPlayMode,
             .bgmPrepared,
             .bgmPlaybackChanged,
             .bgmReachedEnd,
             .bgmFailed,
             .bgmProgressUpdated:
            return true
        default:
            return false
        }
    }

    private static func shouldSyncProjectionFacadeAfterRuntimeAction(_ action: LiveRuntimeAction) -> Bool {
        switch action {
        case .operatorToggledProjection,
             .projectionStartFailed,
             .projectionExternalDisplayLost,
             .projectionExternalDisplayAvailable,
             .projectionExternalDisplayUnavailable:
            return true
        default:
            return false
        }
    }

    private static func shouldSyncPPTFacadeAfterRuntimeAction(_ action: LiveRuntimeAction) -> Bool {
        switch action {
        case .operatorSetPPTMode,
             .operatorToggledPPTMode,
             .pptEventTapStarted,
             .pptEventTapFailed,
             .pptEventTapStopped:
            return true
        default:
            return false
        }
    }

    private static func shouldSyncAutomationNoticeFacadeAfterRuntimeAction(_ action: LiveRuntimeAction) -> Bool {
        switch action {
        case .automationFailed,
             .automationNoticeRequested,
             .automationNoticeExpired,
             .automationNoticeDismissed:
            return true
        default:
            return false
        }
    }

    private static func shouldSyncSupportFacadeAfterRuntimeAction(_ action: LiveRuntimeAction) -> Bool {
        switch action {
        case .supportEventRecorded:
            return true
        default:
            return false
        }
    }

    private static func shouldSyncProgramQueueFacadeAfterRuntimeAction(_ action: LiveRuntimeAction) -> Bool {
        switch action {
        case .operatorAddedProgramItems,
             .operatorRemovedProgramItem,
             .operatorMovedProgramItems,
             .operatorUpdatedProgramItemSchedule,
             .operatorAddedAgendaMarker,
             .facadeLoadedProgramQueue,
             .presentationQueryResultConsumed:
            return true
        default:
            return false
        }
    }

    private static func shouldSyncCurrentProgramFacadeAfterRuntimeAction(_ action: LiveRuntimeAction) -> Bool {
        switch action {
        case .operatorSelectedProgram,
             .operatorSelectedDetachedProgram,
             .operatorClearedCurrentProgram,
             .facadeCurrentProgramChanged,
             .operatorRemovedProgramItem,
             .facadeLoadedProgramQueue,
             .operatorUpdatedProgramItemSchedule,
             .presentationQueryResultConsumed:
            return true
        default:
            return false
        }
    }

    private static func shouldSyncPanicFacadeAfterRuntimeAction(_ action: LiveRuntimeAction) -> Bool {
        switch action {
        case .operatorSetPanic,
             .operatorToggledPanic,
             .panicBGMPauseDelayElapsed:
            return true
        default:
            return false
        }
    }
}
