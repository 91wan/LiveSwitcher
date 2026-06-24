import Foundation

struct LiveRuntimeMutation: Equatable {
    var state: LiveRuntimeState
    var effects: [LiveRuntimeEffect]
}

enum LiveRuntimeReducer {
    static func reduce(
        state: LiveRuntimeState,
        action: LiveRuntimeAction,
        environment: LiveRuntimeEnvironment
    ) -> LiveRuntimeMutation {
        var state = state
        var effects: [LiveRuntimeEffect] = []
        let bridgeMode = environment.bridgeMode
        switch action {
        case .operatorSelectedProgram(let id):
            guard isRuntimeOwned(.programSelection, in: bridgeMode) else { break }
            guard let item = ProgramSelectionRuntimeReducer.selectedProgramItem(id, in: state) else { break }
            ProgramSelectionRuntimeReducer.selectProgram(
                item,
                state: &state,
                effects: &effects,
                now: environment.now,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorSelectedDetachedProgram(let item):
            guard isRuntimeOwned(.programSelection, in: bridgeMode) else { break }
            ProgramSelectionRuntimeReducer.selectProgram(
                item,
                state: &state,
                effects: &effects,
                now: environment.now,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorClearedCurrentProgram:
            guard isRuntimeOwned(.programSelection, in: bridgeMode) else { break }
            ProgramSelectionRuntimeReducer.clearCurrentProgram(
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorRequestedProgramActivation(let id, let plan):
            guard isRuntimeOwned(.programActivation, in: bridgeMode) else { break }
            ProgramActivationRuntimeReducer.request(
                id: id,
                plan: plan,
                state: &state,
                effects: &effects
            )

        case .programActivationCompleted(let id):
            guard isRuntimeOwned(.programActivation, in: bridgeMode) else { break }
            ProgramActivationRuntimeReducer.complete(id: id, state: &state)

        case .operatorToggledMediaPlayback:
            guard isRuntimeOwned(.media, in: bridgeMode) else { break }
            MediaRuntimeReducer.togglePlayback(
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorRestartedCurrentMedia:
            guard isRuntimeOwned(.media, in: bridgeMode) else { break }
            MediaRuntimeReducer.restartCurrent(
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorReturnedCurrentMediaToStart:
            guard isRuntimeOwned(.media, in: bridgeMode) else { break }
            MediaRuntimeReducer.returnCurrentToStart(
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorSeekedCurrentMediaToStart:
            guard isRuntimeOwned(.media, in: bridgeMode) else { break }
            MediaRuntimeReducer.seekCurrentToStart(
                state: &state,
                effects: &effects
            )

        case .operatorSeekedCurrentMediaToEnd:
            guard isRuntimeOwned(.media, in: bridgeMode) else { break }
            MediaRuntimeReducer.seekCurrentToEnd(
                state: &state,
                effects: &effects
            )

        case .operatorStoppedCurrentMedia:
            guard isRuntimeOwned(.media, in: bridgeMode) else { break }
            MediaRuntimeReducer.stopCurrent(
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorPausedMediaForPanic(let generation):
            guard isRuntimeOwned(.media, in: bridgeMode) else { break }
            MediaRuntimeReducer.pauseForPanic(
                generation: generation,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorResumedMediaAfterPanic(let generation):
            guard isRuntimeOwned(.media, in: bridgeMode) else { break }
            MediaRuntimeReducer.resumeAfterPanic(
                generation: generation,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorSelectedAudioStrategy(let strategy):
            guard isRuntimeOwned(.audio, in: bridgeMode) else { break }
            AudioRuntimeReducer.selectStrategy(
                strategy,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorChangedMasterVolume(let volume):
            guard isRuntimeOwned(.audio, in: bridgeMode) else { break }
            AudioRuntimeReducer.changeMasterVolume(
                volume,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorChangedMediaVolume(let volume):
            guard isRuntimeOwned(.audio, in: bridgeMode) else { break }
            AudioRuntimeReducer.changeMediaVolume(
                volume,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorChangedBGMVolume(let volume):
            guard isRuntimeOwned(.audio, in: bridgeMode) else { break }
            AudioRuntimeReducer.changeBGMVolume(
                volume,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorChangedMasterMute(let isMuted):
            guard isRuntimeOwned(.audio, in: bridgeMode) else { break }
            AudioRuntimeReducer.changeMasterMute(
                isMuted,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorChangedMediaMute(let isMuted):
            guard isRuntimeOwned(.audio, in: bridgeMode) else { break }
            AudioRuntimeReducer.changeMediaMute(
                isMuted,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorChangedBGMMute(let isMuted):
            guard isRuntimeOwned(.audio, in: bridgeMode) else { break }
            AudioRuntimeReducer.changeBGMMute(
                isMuted,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorChangedBGMTakeover(let isActive):
            guard isRuntimeOwned(.audio, in: bridgeMode) else { break }
            AudioRuntimeReducer.changeBGMTakeover(
                isActive,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorToggledSpeakerMode:
            guard isRuntimeOwned(.audio, in: bridgeMode) else { break }
            AudioRuntimeReducer.toggleSpeakerMode(
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorSetSpeakerMode(let isEnabled):
            guard isRuntimeOwned(.audio, in: bridgeMode) else { break }
            AudioRuntimeReducer.setSpeakerMode(
                isEnabled,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorToggledPanic:
            guard isRuntimeOwned(.panic, in: bridgeMode) else { break }
            PanicRuntimeReducer.setPanic(
                !state.panic.isActive,
                state: &state,
                effects: &effects,
                liveAudioFadeDuration: environment.liveAudioFadeDuration,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorSetPanic(let isActive):
            guard isRuntimeOwned(.panic, in: bridgeMode) else { break }
            PanicRuntimeReducer.setPanic(
                isActive,
                state: &state,
                effects: &effects,
                liveAudioFadeDuration: environment.liveAudioFadeDuration,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorSelectedBGM(let id):
            guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }
            BGMRuntimeReducer.selectBGM(
                id: id,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorSelectedBGMPlayMode(let playMode):
            guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }
            BGMRuntimeReducer.setPlayMode(playMode, state: &state, effects: &effects)

        case .operatorSeekedBGMToBeginning:
            guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }
            BGMRuntimeReducer.seekToBeginning(state: &state, effects: &effects)

        case .operatorSeekedBGMToProgress(let progress):
            guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }
            BGMRuntimeReducer.seekToProgress(progress, state: &state, effects: &effects)

        case .operatorToggledCurrentBGMPlayback:
            guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }
            BGMRuntimeReducer.toggleCurrentPlayback(
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorStoppedBGM:
            guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }
            BGMRuntimeReducer.stop(
                state: &state,
                effects: &effects,
                liveAudioFadeDuration: environment.liveAudioFadeDuration,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorSelectedNextBGM:
            guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }
            BGMRuntimeReducer.selectAdjacent(
                offset: 1,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorSelectedPreviousBGM:
            guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }
            BGMRuntimeReducer.selectAdjacent(
                offset: -1,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorPausedBGMForPanic(let generation):
            guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }
            BGMRuntimeReducer.pauseForPanic(
                generation: generation,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorResumedBGMAfterPanic(let generation):
            guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }
            BGMRuntimeReducer.resumeAfterPanic(
                generation: generation,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .facadeBGMLibraryChanged(let items):
            guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }
            BGMRuntimeReducer.replaceLibrary(
                items,
                state: &state,
                effects: &effects,
                liveAudioFadeDuration: environment.liveAudioFadeDuration,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorToggledPPTMode(let source):
            guard isRuntimeOwned(.ppt, in: bridgeMode) else { break }
            PPTRuntimeReducer.toggleMode(
                source: source,
                state: &state,
                effects: &effects
            )

        case .operatorSetPPTMode(let isEnabled, let source):
            guard isRuntimeOwned(.ppt, in: bridgeMode) else { break }
            PPTRuntimeReducer.setMode(
                isEnabled,
                source: source,
                state: &state,
                effects: &effects
            )

        case .operatorToggledProjection:
            guard isRuntimeOwned(.projection, in: bridgeMode) else { break }
            ProjectionRuntimeReducer.toggleProjection(
                state: &state,
                effects: &effects,
                canWriteSupport: canGenerateReducerSupport(in: bridgeMode),
                now: environment.now
            )

        case .operatorSetConsoleMode(let mode):
            guard isRuntimeOwned(.persistence, in: bridgeMode) else { break }
            PreferencesRuntimeReducer.setConsoleMode(mode, state: &state, effects: &effects)

        case .operatorSetThemeOverride(let theme):
            guard isRuntimeOwned(.persistence, in: bridgeMode) else { break }
            PreferencesRuntimeReducer.setThemeOverride(theme, state: &state, effects: &effects)

        case .operatorSetActiveWallpaperURL(let url):
            guard isRuntimeOwned(.persistence, in: bridgeMode),
                  isRuntimeOwned(.imageAssets, in: bridgeMode)
            else { break }
            PreferencesRuntimeReducer.setActiveWallpaperURL(url, state: &state, effects: &effects)

        case .operatorSetCornerLogoURL(let url):
            guard isRuntimeOwned(.persistence, in: bridgeMode),
                  isRuntimeOwned(.imageAssets, in: bridgeMode)
            else { break }
            PreferencesRuntimeReducer.setCornerLogoURL(url, state: &state, effects: &effects)

        case .operatorSetAutoPlayNextVideoOnEnd(let isEnabled):
            guard isRuntimeOwned(.persistence, in: bridgeMode) else { break }
            PreferencesRuntimeReducer.setAutoPlayNextVideoOnEnd(isEnabled, state: &state, effects: &effects)

        case .operatorSetAutoAdvanceAtScheduledTime(let isEnabled):
            guard isRuntimeOwned(.persistence, in: bridgeMode) else { break }
            PreferencesRuntimeReducer.setAutoAdvanceAtScheduledTime(isEnabled, state: &state, effects: &effects)

        case .operatorSetShowAgendaTimeline(let isEnabled):
            guard isRuntimeOwned(.persistence, in: bridgeMode) else { break }
            PreferencesRuntimeReducer.setShowAgendaTimeline(isEnabled, state: &state, effects: &effects)

        case .operatorSetCornerLogoPosition(let position):
            guard isRuntimeOwned(.persistence, in: bridgeMode) else { break }
            PreferencesRuntimeReducer.setCornerLogoPosition(position, state: &state, effects: &effects)

        case .operatorAddedProgramItems(let items):
            guard isRuntimeOwned(.programQueue, in: bridgeMode) else { break }
            ProgramQueueRuntimeReducer.addProgramItems(items, state: &state)

        case .operatorRemovedProgramItem(let id):
            guard isRuntimeOwned(.programQueue, in: bridgeMode) else { break }
            ProgramQueueRuntimeReducer.removeProgramItem(id: id, state: &state)

        case .operatorMovedProgramItems(let fromOffsets, let toOffset):
            guard isRuntimeOwned(.programQueue, in: bridgeMode) else { break }
            ProgramQueueRuntimeReducer.moveProgramItems(fromOffsets: fromOffsets, toOffset: toOffset, state: &state)

        case .operatorUpdatedProgramItemSchedule(let id, let scheduledStartAt, let scheduledDuration):
            guard isRuntimeOwned(.programQueue, in: bridgeMode) else { break }
            ProgramQueueRuntimeReducer.updateProgramItemSchedule(
                id: id,
                scheduledStartAt: scheduledStartAt,
                scheduledDuration: scheduledDuration,
                state: &state
            )

        case .operatorAddedAgendaMarker(let title):
            guard isRuntimeOwned(.programQueue, in: bridgeMode) else { break }
            ProgramQueueRuntimeReducer.addAgendaMarker(title: title, state: &state)

        case .facadeLoadedProgramQueue(let items):
            guard isRuntimeOwned(.programQueue, in: bridgeMode) else { break }
            ProgramQueueRuntimeReducer.loadProgramQueueFromFacade(items, state: &state)

        case .mediaLoaded(let url, let generation):
            guard isRuntimeOwned(.media, in: bridgeMode) else { break }
            MediaRuntimeReducer.loaded(
                url: url,
                generation: generation,
                state: &state
            )

        case .mediaPlaybackChanged(let isPlaying, let generation):
            guard isRuntimeOwned(.media, in: bridgeMode) else { break }
            MediaRuntimeReducer.playbackChanged(
                isPlaying: isPlaying,
                generation: generation,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .mediaReachedEnd(let generation):
            guard isRuntimeOwned(.media, in: bridgeMode) else { break }
            MediaRuntimeReducer.reachedEnd(
                generation: generation,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .mediaSeekCompleted(let time, let generation):
            guard isRuntimeOwned(.media, in: bridgeMode) else { break }
            MediaRuntimeReducer.seekCompleted(
                time: time,
                generation: generation,
                state: &state
            )

        case .facadeAudioInputsChanged(let snapshot):
            guard isRuntimeOwned(.audio, in: bridgeMode) else { break }
            AudioRuntimeReducer.applyFacadeSnapshot(
                snapshot,
                to: &state,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .bgmPlaybackChanged(let isPlaying, let generation):
            guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }
            BGMRuntimeReducer.playbackChanged(
                isPlaying: isPlaying,
                generation: generation,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .bgmReachedEnd(let generation):
            guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }
            BGMRuntimeReducer.reachedEnd(
                generation: generation,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .bgmFailed(let reason, let generation):
            guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }
            BGMRuntimeReducer.failed(
                reason: reason,
                generation: generation,
                state: &state,
                effects: &effects,
                canWriteSupport: canGenerateReducerSupport(in: bridgeMode),
                now: environment.now,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .bgmProgressUpdated(let time, let duration, let generation):
            guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }
            BGMRuntimeReducer.progressUpdated(
                time: time,
                duration: duration,
                generation: generation,
                state: &state
            )

        case .panicBGMPauseDelayElapsed(let generation, let snapshot):
            guard isRuntimeOwned(.panic, in: bridgeMode) else { break }
            PanicRuntimeReducer.bgmPauseDelayElapsed(
                generation: generation,
                snapshot: snapshot,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .projectionStartFailed(let reason):
            guard isRuntimeOwned(.projection, in: bridgeMode) else { break }
            ProjectionRuntimeReducer.startFailed(reason: reason, state: &state)

        case .projectionExternalDisplayLost:
            guard isRuntimeOwned(.projection, in: bridgeMode) else { break }
            ProjectionRuntimeReducer.externalDisplayLost(
                state: &state,
                effects: &effects,
                canWriteSupport: canGenerateReducerSupport(in: bridgeMode),
                now: environment.now
            )

        case .projectionExternalDisplayAvailable:
            guard isRuntimeOwned(.projection, in: bridgeMode) else { break }
            ProjectionRuntimeReducer.externalDisplayAvailable(state: &state)

        case .projectionExternalDisplayUnavailable:
            guard isRuntimeOwned(.projection, in: bridgeMode) else { break }
            ProjectionRuntimeReducer.externalDisplayUnavailable(
                state: &state,
                effects: &effects,
                now: environment.now
            )

        case .pptEventTapStarted:
            guard isRuntimeOwned(.ppt, in: bridgeMode) else { break }
            PPTRuntimeReducer.eventTapStarted(state: &state)

        case .pptEventTapFailed(let reason):
            guard isRuntimeOwned(.ppt, in: bridgeMode) else { break }
            PPTRuntimeReducer.eventTapFailed(reason: reason, state: &state)

        case .pptEventTapStopped(let reason):
            guard isRuntimeOwned(.ppt, in: bridgeMode) else { break }
            PPTRuntimeReducer.eventTapStopped(reason: reason, state: &state)

        case .automationScriptRequested(let script, let action):
            guard isRuntimeOwned(.automationCommand, in: bridgeMode) else { break }
            AutomationCommandRuntimeReducer.requestScript(
                script: script,
                action: action,
                effects: &effects
            )

        case .automationFailed(let action, let sanitizedMessage):
            guard isRuntimeOwned(.automationNotice, in: bridgeMode) else { break }
            AutomationNoticeRuntimeReducer.request(
                action: action,
                state: &state,
                effects: &effects,
                now: environment.now
            )
            if canGenerateReducerSupport(in: bridgeMode) {
                SupportRuntimeReducer.record(
                    kind: .appleScriptFailed,
                    detail: "action=\(action),error=\(sanitizedMessage)",
                    at: environment.now,
                    state: &state
                )
            }

        case .automationNoticeRequested(let action):
            guard isRuntimeOwned(.automationNotice, in: bridgeMode) else { break }
            AutomationNoticeRuntimeReducer.request(
                action: action,
                state: &state,
                effects: &effects,
                now: environment.now
            )

        case .automationNoticeExpired(let id):
            guard isRuntimeOwned(.automationNotice, in: bridgeMode) else { break }
            AutomationNoticeRuntimeReducer.expire(id: id, state: &state)

        case .automationNoticeDismissed:
            guard isRuntimeOwned(.automationNotice, in: bridgeMode) else { break }
            AutomationNoticeRuntimeReducer.dismiss(state: &state)

        case .operatorRequestedPresentationQuery(let id):
            guard isRuntimeOwned(.presentationQuery, in: bridgeMode) else { break }
            PresentationQueryRuntimeReducer.request(
                id: id,
                state: &state,
                effects: &effects
            )

        case .presentationQueryCompleted(let id, let result):
            guard isRuntimeOwned(.presentationQuery, in: bridgeMode) else { break }
            PresentationQueryRuntimeReducer.complete(id: id, result: result, state: &state)

        case .presentationQueryFailed(let id, let action, let sanitizedMessage):
            guard isRuntimeOwned(.presentationQuery, in: bridgeMode) else { break }
            PresentationQueryRuntimeReducer.fail(
                id: id,
                action: action,
                sanitizedMessage: sanitizedMessage,
                state: &state
            )

        case .presentationQueryResultConsumed(let id):
            guard isRuntimeOwned(.presentationQuery, in: bridgeMode) else { break }
            PresentationQueryRuntimeReducer.consumeResult(id: id, state: &state)

        case .supportEventRecorded(let event):
            guard isRuntimeOwned(.support, in: bridgeMode) else { break }
            SupportRuntimeReducer.record(event: event, state: &state, effects: &effects)
        }

        return LiveRuntimeMutation(
            state: state,
            effects: effects.filter { isEffectAllowed($0, in: environment.bridgeMode) }
        )
    }

    private static func isEffectAllowed(_ effect: LiveRuntimeEffect, in bridgeMode: LiveRuntimeBridgeMode) -> Bool {
        if bridgeMode == .fullRuntime { return true }
        if bridgeMode == .recordingOnly { return false }

        return bridgeMode.owns(effect.requiredBridgeDomain)
    }

    private static func isRuntimeOwned(_ domain: LiveRuntimeDomain, in bridgeMode: LiveRuntimeBridgeMode) -> Bool {
        bridgeMode.owns(domain)
    }

    private static func canGenerateReducerSupport(in bridgeMode: LiveRuntimeBridgeMode) -> Bool {
        bridgeMode == .fullRuntime
    }
}
