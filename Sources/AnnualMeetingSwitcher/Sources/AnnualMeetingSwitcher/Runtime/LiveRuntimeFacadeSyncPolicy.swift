import Foundation

struct LiveRuntimeFacadeSyncOptions: Equatable {
    var dispatchAudioInputsChanged: Bool
    var syncBGM: Bool
    var syncProjection: Bool
    var syncPPT: Bool
    var syncAutomationNotice: Bool
    var syncSupport: Bool
}

enum LiveRuntimeFacadeSyncPolicy {
    static func options(for action: LiveRuntimeAction) -> LiveRuntimeFacadeSyncOptions {
        LiveRuntimeFacadeSyncOptions(
            dispatchAudioInputsChanged: shouldDispatchAudioInputsBeforeRuntimeAction(action),
            syncBGM: shouldSyncBGMFacadeAfterRuntimeAction(action),
            syncProjection: shouldSyncProjectionFacadeAfterRuntimeAction(action),
            syncPPT: shouldSyncPPTFacadeAfterRuntimeAction(action),
            syncAutomationNotice: shouldSyncAutomationNoticeFacadeAfterRuntimeAction(action),
            syncSupport: shouldSyncSupportFacadeAfterRuntimeAction(action)
        )
    }

    private static func shouldDispatchAudioInputsBeforeRuntimeAction(_ action: LiveRuntimeAction) -> Bool {
        switch action {
        case .operatorSelectedAudioStrategy,
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
             .bgmPlaybackChanged,
             .bgmReachedEnd,
             .bgmFailed,
             .operatorPausedBGMForPanic,
             .operatorResumedBGMAfterPanic,
             .operatorRequestedPresentationQuery,
             .presentationQueryCompleted,
             .presentationQueryFailed,
             .presentationQueryResultConsumed,
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
}
