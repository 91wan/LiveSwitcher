extension LiveRuntimeEffect {
    var redactedForRecording: LiveRuntimeEffect {
        switch self {
        case .executeProgramActivation(let id, let plan):
            return .executeProgramActivation(id: id, plan: plan.redactedForRecording)
        case .runAppleScript(_, let action):
            return .runAppleScript(script: "<redacted>", action: action)
        case .saveCompanyDisplayName:
            return .saveCompanyDisplayName("<redacted>")
        default:
            return self
        }
    }

    var requiredBridgeDomain: LiveRuntimeDomain {
        switch self {
        case .applyAudioRouting:
            return .audio

        case .loadBackgroundImage,
             .loadCornerLogoImage:
            return .imageAssets

        case .saveConsoleMode,
             .saveThemeOverride,
             .saveCompanyDisplayName,
             .saveAudioStrategy,
             .saveSpeakerMode,
             .saveBGMPlayMode,
             .saveAutoPlayNextVideoOnEnd,
             .saveAgendaTimeReminderEnabled,
             .saveShowAgendaTimeline,
             .saveCornerLogoVisible,
             .saveCornerLogoPosition,
             .savePersistentState:
            return .persistence

        case .loadMedia,
             .playMedia,
             .pauseMedia,
             .restartMedia,
             .seekMediaToStart,
             .seekMediaToEnd,
             .seekMediaToProgress,
             .stopMedia,
             .setMediaVolume:
            return .media

        case .prepareBGM,
             .playBGM,
             .pauseBGM,
             .stopBGM,
             .setBGMVolume,
             .seekBGMToBeginning,
             .seekBGMToProgress,
             .setBGMPlayMode,
             .startBGMTimer,
             .stopBGMTimer:
            return .bgm

        case .schedulePanicBGMPause,
             .cancelPanicBGMPause:
            return .panic

        case .startProjection,
             .stopProjection,
             .showOutputWindow,
             .hideOutputWindow:
            return .projection

        case .startPPTEventTap,
             .stopPPTEventTap:
            return .ppt

        case .executeProgramActivation:
            return .programActivation

        case .runAppleScript:
            return .automationCommand

        case .scanPresentationQuery:
            return .presentationQuery

        case .showAutomationNotice,
             .expireAutomationNotice:
            return .automationNotice

        case .recordSupportEvent:
            return .support
        }
    }
}
