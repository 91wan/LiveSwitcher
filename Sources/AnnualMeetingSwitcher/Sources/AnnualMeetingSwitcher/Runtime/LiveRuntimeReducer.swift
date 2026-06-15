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
            state.programActivation.startRequest(id: id)
            effects.append(.executeProgramActivation(id: id, plan: plan))

        case .programActivationCompleted(let id):
            guard isRuntimeOwned(.programActivation, in: bridgeMode) else { break }
            state.programActivation.completeRequest(id: id)

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

        case .operatorToggledPPTMode(let source):
            guard isRuntimeOwned(.ppt, in: bridgeMode) else { break }
            reducePPTModeSet(
                !(state.ppt.isRequested || state.ppt.isEventTapActive),
                source: source,
                state: &state,
                effects: &effects
            )

        case .operatorSetPPTMode(let isEnabled, let source):
            guard isRuntimeOwned(.ppt, in: bridgeMode) else { break }
            reducePPTModeSet(
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
            state.mode = mode
            effects.append(.saveConsoleMode(mode))

        case .operatorSetThemeOverride(let theme):
            state.preferences.themeOverride = theme
            effects.append(.saveThemeOverride(theme))

        case .operatorSetActiveWallpaperURL(let url):
            state.preferences.activeWallpaperURL = url
            effects.append(.loadBackgroundImage(url))

        case .operatorSetCornerLogoURL(let url):
            state.preferences.cornerLogoURL = url
            effects.append(.loadCornerLogoImage(url))

        case .operatorSetAutoPlayNextVideoOnEnd(let isEnabled):
            state.preferences.autoPlayNextVideoOnEnd = isEnabled
            effects.append(.saveAutoPlayNextVideoOnEnd(isEnabled))

        case .operatorSetAutoAdvanceAtScheduledTime(let isEnabled):
            state.preferences.autoAdvanceAtScheduledTime = isEnabled
            effects.append(.saveAutoAdvanceAtScheduledTime(isEnabled))

        case .operatorSetShowAgendaTimeline(let isEnabled):
            state.preferences.showAgendaTimeline = isEnabled
            effects.append(.saveShowAgendaTimeline(isEnabled))

        case .operatorSetCornerLogoPosition(let position):
            state.preferences.cornerLogoPosition = position
            effects.append(.saveCornerLogoPosition(position))

        case .operatorAddedProgramItems(let items):
            guard isRuntimeOwned(.programQueue, in: bridgeMode) else { break }
            state.program.appendProgramItems(items)

        case .operatorRemovedProgramItem(let id):
            guard isRuntimeOwned(.programQueue, in: bridgeMode) else { break }
            state.program.removeProgramItem(id: id)

        case .operatorMovedProgramItems(let fromOffsets, let toOffset):
            guard isRuntimeOwned(.programQueue, in: bridgeMode) else { break }
            state.program.moveProgramItems(fromOffsets: fromOffsets, toOffset: toOffset)

        case .operatorUpdatedProgramItemSchedule(let id, let scheduledStartAt, let scheduledDuration):
            guard isRuntimeOwned(.programQueue, in: bridgeMode) else { break }
            state.program.updateProgramItemSchedule(
                id: id,
                scheduledStartAt: scheduledStartAt,
                scheduledDuration: scheduledDuration
            )

        case .operatorAddedAgendaMarker(let title):
            guard isRuntimeOwned(.programQueue, in: bridgeMode) else { break }
            state.program.appendAgendaMarker(title: title)

        case .facadeLoadedProgramQueue(let items):
            guard isRuntimeOwned(.programQueue, in: bridgeMode) else { break }
            state.program.replaceProgramQueueFromFacade(items)

        case .mediaLoaded(let url, let generation):
            MediaRuntimeReducer.loaded(
                url: url,
                generation: generation,
                state: &state
            )

        case .mediaPlaybackChanged(let isPlaying, let generation):
            MediaRuntimeReducer.playbackChanged(
                isPlaying: isPlaying,
                generation: generation,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .mediaReachedEnd(let generation):
            MediaRuntimeReducer.reachedEnd(
                generation: generation,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .mediaSeekCompleted(let time, let generation):
            MediaRuntimeReducer.seekCompleted(
                time: time,
                generation: generation,
                state: &state
            )

        case .facadeCurrentProgramChanged(let id):
            state.program.currentID = id
            if let id, state.program.items.contains(where: { $0.id == id }) {
                state.program.currentDetachedItem = nil
            } else if state.program.currentDetachedItem?.id != id {
                state.program.currentDetachedItem = nil
            }
            state.program.currentSwitchedAt = id == nil ? nil : environment.now
            state.audio.routingContext.isCurrentProgramMediaSource = state.program.effectiveCurrentItem?.sourceKind == .media
            AudioRuntimeReducer.recalculateAudio(&state, speakerModeDuckedRatio: environment.speakerModeDuckedRatio)
            effects.append(.applyAudioRouting(reason: .programChanged))

        case .facadeAudioInputsChanged(let snapshot):
            guard isRuntimeOwned(.audio, in: bridgeMode) else { break }
            AudioRuntimeReducer.applyFacadeSnapshot(
                snapshot,
                to: &state,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .bgmPrepared(let id, let generation):
            guard generation == state.bgm.generation, id == state.bgm.currentID else { break }

        case .bgmPlaybackChanged(let isPlaying, let generation):
            BGMRuntimeReducer.playbackChanged(
                isPlaying: isPlaying,
                generation: generation,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .bgmReachedEnd(let generation):
            BGMRuntimeReducer.reachedEnd(
                generation: generation,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .bgmFailed(let reason, let generation):
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
            BGMRuntimeReducer.progressUpdated(
                time: time,
                duration: duration,
                generation: generation,
                state: &state
            )

        case .panicFadeCompleted:
            break

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
            state.ppt.isRequested = true
            state.ppt.isEventTapActive = true
            state.ppt.lastFailureReason = nil

        case .pptEventTapFailed(let reason):
            state.ppt.isRequested = false
            state.ppt.isEventTapActive = false
            state.ppt.lastFailureReason = reason

        case .pptEventTapStopped:
            state.ppt.isRequested = false
            state.ppt.isEventTapActive = false

        case .automationScriptRequested(let script, let action):
            guard isRuntimeOwned(.automationCommand, in: bridgeMode) else { break }
            effects.append(.runAppleScript(script: script, action: action))

        case .automationFailed(let action, let sanitizedMessage):
            requestAutomationNotice(action: action, state: &state, effects: &effects, now: environment.now)
            if canGenerateReducerSupport(in: bridgeMode) {
                state.support.record(
                    kind: .appleScriptFailed,
                    detail: "action=\(action),error=\(sanitizedMessage)",
                    at: environment.now
                )
            }

        case .automationNoticeRequested(let action):
            requestAutomationNotice(action: action, state: &state, effects: &effects, now: environment.now)

        case .automationNoticeExpired(let id):
            if state.automation.notice?.id == id {
                state.automation.notice = nil
            }

        case .automationNoticeDismissed:
            state.automation.notice = nil

        case .operatorRequestedPresentationQuery(let id):
            guard isRuntimeOwned(.presentationQuery, in: bridgeMode) else { break }
            state.presentationQuery.activeRequestID = id
            state.presentationQuery.latestCompletedRequestID = nil
            state.presentationQuery.latestResult = nil
            state.presentationQuery.latestFailure = nil
            effects.append(.scanPresentationQuery(id: id))

        case .presentationQueryCompleted(let id, let result):
            guard isRuntimeOwned(.presentationQuery, in: bridgeMode) else { break }
            guard state.presentationQuery.activeRequestID == id else { break }
            state.presentationQuery.activeRequestID = nil
            state.presentationQuery.latestCompletedRequestID = id
            state.presentationQuery.latestResult = result
            state.presentationQuery.latestFailure = nil

        case .presentationQueryFailed(let id, let action, let sanitizedMessage):
            guard isRuntimeOwned(.presentationQuery, in: bridgeMode) else { break }
            guard state.presentationQuery.activeRequestID == id else { break }
            state.presentationQuery.activeRequestID = nil
            state.presentationQuery.latestCompletedRequestID = nil
            state.presentationQuery.latestResult = nil
            state.presentationQuery.latestFailure = PresentationQueryFailure(
                id: id,
                action: action,
                sanitizedMessage: sanitizedMessage
            )

        case .presentationQueryResultConsumed(let id):
            guard isRuntimeOwned(.presentationQuery, in: bridgeMode) else { break }
            state.presentationQuery.markConsumed(id)

        case .supportEventRecorded(let event):
            if let accepted = state.support.record(event: event) {
                effects.append(.recordSupportEvent(accepted))
            }
        }

        return LiveRuntimeMutation(
            state: state,
            effects: effects.filter { isEffectAllowed($0, in: environment.bridgeMode) }
        )
    }

    private static func reducePPTModeSet(
        _ isEnabled: Bool,
        source: PPTModeToggleSource,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        _ = source
        if isEnabled {
            guard !state.ppt.isRequested, !state.ppt.isEventTapActive else { return }
            state.ppt.isRequested = true
            state.ppt.isEventTapActive = false
            state.ppt.lastFailureReason = nil
            effects.append(.startPPTEventTap)
            return
        }

        guard state.ppt.isRequested || state.ppt.isEventTapActive else { return }
        state.ppt.isRequested = false
        state.ppt.isEventTapActive = false
        effects.append(.stopPPTEventTap(reason: .operatorDisabled))
    }

    private static func requestAutomationNotice(
        action: String,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        now: Date
    ) {
        state.automation.suppressionUntilByAction = state.automation.suppressionUntilByAction.filter { _, expiry in
            expiry > now
        }
        let notice = AutomationRuntimeNoticePolicy.make(action: action, createdAt: now)
        let suppressionUntil = state.automation.suppressionUntilByAction[action] ?? .distantPast
        guard suppressionUntil <= now else { return }

        state.automation.notice = notice
        state.automation.suppressionUntilByAction[action] = now.addingTimeInterval(15)
        effects.append(.showAutomationNotice(notice))
        if let expiresAt = notice.expiresAt {
            effects.append(.expireAutomationNotice(notice.id, at: expiresAt))
        }
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
