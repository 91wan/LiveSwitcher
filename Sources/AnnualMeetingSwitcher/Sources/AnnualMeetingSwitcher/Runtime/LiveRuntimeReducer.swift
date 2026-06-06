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
        func recalculateAudio(_ state: inout LiveRuntimeState) {
            Self.recalculateAudio(
                &state,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )
        }

        switch action {
        case .operatorSelectedProgram(let id):
            guard isRuntimeOwned(.media, in: bridgeMode) else { break }
            guard let item = selectedProgramItem(id, in: state) else { break }
            reduceSelectedProgram(
                item,
                state: &state,
                effects: &effects,
                now: environment.now,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorSelectedDetachedProgram(let item):
            guard isRuntimeOwned(.media, in: bridgeMode) else { break }
            reduceSelectedProgram(
                item,
                state: &state,
                effects: &effects,
                now: environment.now,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorToggledMediaPlayback:
            guard isRuntimeOwned(.media, in: bridgeMode) else { break }
            guard !state.media.didPlayToEnd else { break }
            state.media.isPlaying.toggle()
            syncAudioRoutingContextFromMirrorState(&state)
            effects.append(state.media.isPlaying ? .playMedia(generation: state.media.generation) : .pauseMedia(generation: state.media.generation))
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .mediaPlaybackChanged))

        case .operatorRestartedCurrentMedia:
            guard isRuntimeOwned(.media, in: bridgeMode) else { break }
            guard state.program.effectiveCurrentItem?.supportsSeeking == true else { break }
            state.media.didPlayToEnd = false
            state.media.currentTime = 0
            state.media.isPlaying = !state.panic.isActive
            syncAudioRoutingContextFromMirrorState(&state)
            effects.append(.restartMedia(generation: state.media.generation))
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .mediaPlaybackChanged))

        case .operatorSeekedCurrentMediaToStart:
            guard isRuntimeOwned(.media, in: bridgeMode) else { break }
            guard state.program.effectiveCurrentItem?.supportsSeeking == true else { break }
            state.media.didPlayToEnd = false
            state.media.currentTime = 0
            effects.append(.seekMediaToStart(generation: state.media.generation))

        case .operatorSeekedCurrentMediaToEnd:
            guard isRuntimeOwned(.media, in: bridgeMode) else { break }
            guard state.program.effectiveCurrentItem?.supportsSeeking == true else { break }
            state.media.didPlayToEnd = false
            if let duration = state.media.duration, duration.isFinite, duration > 0 {
                state.media.currentTime = duration
            }
            effects.append(.seekMediaToEnd(generation: state.media.generation))

        case .operatorStoppedCurrentMedia:
            guard isRuntimeOwned(.media, in: bridgeMode) else { break }
            guard state.media.loadedURL != nil
                    || state.media.isPlaying
                    || state.program.effectiveCurrentItem?.sourceKind == .media
            else { break }
            state.media.generation += 1
            state.media.loadedURL = nil
            state.media.isPlaying = false
            state.media.didPlayToEnd = false
            state.media.currentTime = 0
            state.media.duration = nil
            syncAudioRoutingContextFromMirrorState(&state)
            effects.append(.stopMedia(generation: state.media.generation))
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .mediaPlaybackChanged))

        case .operatorPausedMediaForPanic(let generation):
            guard isRuntimeOwned(.media, in: bridgeMode) else { break }
            let targetGeneration = generation ?? state.media.generation
            guard targetGeneration == state.media.generation else { break }
            guard state.media.isPlaying else { break }
            state.media.isPlaying = false
            syncAudioRoutingContextFromMirrorState(&state)
            effects.append(.pauseMedia(generation: targetGeneration))
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .panicChanged))

        case .operatorResumedMediaAfterPanic(let generation):
            guard isRuntimeOwned(.media, in: bridgeMode) else { break }
            let targetGeneration = generation ?? state.media.generation
            guard targetGeneration == state.media.generation else { break }
            state.media.isPlaying = true
            state.media.didPlayToEnd = false
            syncAudioRoutingContextFromMirrorState(&state)
            effects += [
                .setMediaVolume(0, fade: 0, generation: targetGeneration),
                .playMedia(generation: targetGeneration)
            ]
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .panicChanged))

        case .operatorSelectedAudioStrategy(let strategy):
            state.audio.strategy = strategy
            recalculateAudio(&state)
            effects += [
                .applyAudioRouting(reason: .strategyChanged),
                .saveAudioStrategy(strategy)
            ]

        case .operatorChangedMasterVolume(let volume):
            state.audio.masterVolume = min(max(volume, 0), 1)
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .operatorFaderChanged))

        case .operatorChangedMediaVolume(let volume):
            state.audio.mediaVolume = min(max(volume, 0), 1)
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .operatorFaderChanged))

        case .operatorChangedBGMVolume(let volume):
            state.audio.bgmVolume = min(max(volume, 0), 1)
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .operatorFaderChanged))

        case .operatorChangedMasterMute(let isMuted):
            state.audio.isMasterMuted = isMuted
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .operatorFaderChanged))

        case .operatorChangedMediaMute(let isMuted):
            state.audio.isMediaMuted = isMuted
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .operatorFaderChanged))

        case .operatorChangedBGMMute(let isMuted):
            state.audio.isBGMMuted = isMuted
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .operatorFaderChanged))

        case .operatorChangedBGMTakeover(let isActive):
            state.audio.isBGMTakeoverActive = isActive
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .limiterChanged))

        case .operatorToggledSpeakerMode:
            state.audio.isSpeakerMode.toggle()
            recalculateAudio(&state)
            effects += [
                .applyAudioRouting(reason: .speakerChanged),
                .saveSpeakerMode(state.audio.isSpeakerMode)
            ]

        case .operatorSetSpeakerMode(let isEnabled):
            state.audio.isSpeakerMode = isEnabled
            recalculateAudio(&state)
            effects += [
                .applyAudioRouting(reason: .speakerChanged),
                .saveSpeakerMode(isEnabled)
            ]

        case .operatorToggledPanic:
            guard isRuntimeOwned(.panic, in: bridgeMode) else { break }
            reducePanicToggle(
                state: &state,
                effects: &effects,
                now: environment.now,
                canWriteSupport: canGenerateReducerSupport(in: bridgeMode),
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorSetPanic(let isActive):
            guard isRuntimeOwned(.panic, in: bridgeMode) else { break }
            guard state.panic.isActive != isActive else { break }
            reducePanicToggle(
                state: &state,
                effects: &effects,
                now: environment.now,
                canWriteSupport: canGenerateReducerSupport(in: bridgeMode),
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorSelectedBGM(let id):
            guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }
            guard let item = state.bgm.items.first(where: { $0.id == id }) else { break }
            state.bgm.generation += 1
            state.bgm.currentID = id
            state.bgm.progress = 0
            state.bgm.currentTime = 0
            state.bgm.duration = nil
            if state.panic.isActive {
                state.bgm.isPlaying = false
                effects += [
                    .stopBGM(fade: 0, generation: state.bgm.generation),
                    .stopBGMTimer(generation: state.bgm.generation),
                    .applyAudioRouting(reason: .bgmPlaybackChanged)
                ]
            } else {
                state.bgm.isPlaying = true
                effects += [
                    .prepareBGM(item, generation: state.bgm.generation),
                    .playBGM(generation: state.bgm.generation),
                    .startBGMTimer(generation: state.bgm.generation),
                    .applyAudioRouting(reason: .bgmPlaybackChanged)
                ]
            }
            syncAudioRoutingContextFromMirrorState(&state)
            recalculateAudio(&state)

        case .operatorSelectedBGMPlayMode(let playMode):
            state.bgm.playMode = playMode
            effects += [
                .setBGMPlayMode(playMode, generation: state.bgm.currentID == nil ? nil : state.bgm.generation),
                .saveBGMPlayMode(playMode)
            ]

        case .operatorSeekedBGMToBeginning:
            guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }
            guard state.bgm.currentID != nil else { break }
            state.bgm.progress = 0
            state.bgm.currentTime = 0
            effects.append(.seekBGMToBeginning(generation: state.bgm.generation))

        case .operatorSeekedBGMToProgress(let progress):
            guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }
            guard state.bgm.currentID != nil else { break }
            let clampedProgress = min(max(progress, 0), 1)
            state.bgm.progress = clampedProgress
            if let duration = state.bgm.duration, duration.isFinite, duration > 0 {
                state.bgm.currentTime = duration * clampedProgress
            }
            effects.append(.seekBGMToProgress(clampedProgress, generation: state.bgm.generation))

        case .operatorStoppedBGM:
            guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }
            state.bgm.generation += 1
            state.bgm.isPlaying = false
            effects += [
                .stopBGM(fade: environment.liveAudioFadeDuration, generation: state.bgm.generation),
                .stopBGMTimer(generation: state.bgm.generation),
                .applyAudioRouting(reason: .bgmPlaybackChanged)
            ]
            syncAudioRoutingContextFromMirrorState(&state)
            recalculateAudio(&state)

        case .operatorSelectedNextBGM:
            guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }
            selectAdjacentBGM(
                offset: 1,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorSelectedPreviousBGM:
            guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }
            selectAdjacentBGM(
                offset: -1,
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorPausedBGMForPanic(let generation):
            guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }
            let targetGeneration = generation ?? state.bgm.generation
            guard targetGeneration == state.bgm.generation else { break }
            guard state.bgm.isPlaying else { break }
            state.bgm.isPlaying = false
            syncAudioRoutingContextFromMirrorState(&state)
            effects.append(.pauseBGM(generation: targetGeneration))
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .panicChanged))

        case .operatorResumedBGMAfterPanic(let generation):
            guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }
            let targetGeneration = generation ?? state.bgm.generation
            guard targetGeneration == state.bgm.generation else { break }
            state.bgm.isPlaying = true
            syncAudioRoutingContextFromMirrorState(&state)
            effects += [
                .setBGMVolume(0, fade: 0, generation: targetGeneration),
                .playBGM(generation: targetGeneration)
            ]
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .panicChanged))

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
            if state.projection.isBroadcasting {
                state.projection.isBroadcasting = false
                state.projection.safetyNotice = nil
                effects.append(.stopProjection)
                if canGenerateReducerSupport(in: bridgeMode) {
                    state.support.record(kind: .projectionStopped, detail: "source=runtime", at: environment.now)
                }
            } else if state.projection.hasExternalDisplay {
                state.projection.isBroadcasting = true
                state.projection.safetyNotice = nil
                effects.append(.startProjection)
                if canGenerateReducerSupport(in: bridgeMode) {
                    state.support.record(kind: .projectionStarted, detail: "source=runtime", at: environment.now)
                }
            } else {
                state.projection.isBroadcasting = false
                state.projection.hasExternalDisplay = false
                state.projection.safetyNotice = "未检测到外接屏幕，未开始投射"
                if canGenerateReducerSupport(in: bridgeMode) {
                    state.support.record(kind: .projectionStartFailed, detail: "reason=noExternalDisplay", at: environment.now)
                }
            }

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
            guard !items.isEmpty else { break }
            state.program.items.append(contentsOf: items)

        case .operatorRemovedProgramItem(let id):
            guard isRuntimeOwned(.programQueue, in: bridgeMode) else { break }
            state.program.items.removeAll { $0.id == id }
            if state.program.currentID == id {
                state.program.currentID = nil
            }

        case .operatorMovedProgramItems(let fromOffsets, let toOffset):
            guard isRuntimeOwned(.programQueue, in: bridgeMode) else { break }
            moveProgramItems(&state.program.items, fromOffsets: fromOffsets, toOffset: toOffset)

        case .operatorUpdatedProgramItemSchedule(let id, let scheduledStartAt, let scheduledDuration):
            guard isRuntimeOwned(.programQueue, in: bridgeMode) else { break }
            guard let index = state.program.items.firstIndex(where: { $0.id == id }) else { break }
            state.program.items[index].scheduledStartAt = scheduledStartAt
            state.program.items[index].scheduledDuration = scheduledDuration

        case .operatorAddedAgendaMarker(let title):
            guard isRuntimeOwned(.programQueue, in: bridgeMode) else { break }
            let start = state.program.items.last.flatMap { item -> Date? in
                guard let scheduledStartAt = item.scheduledStartAt,
                      let scheduledDuration = item.scheduledDuration
                else { return nil }
                return scheduledStartAt.addingTimeInterval(scheduledDuration)
            }
            state.program.items.append(ProgramItem.agendaMarker(title: title, scheduledStartAt: start))

        case .facadeLoadedProgramQueue(let items):
            guard isRuntimeOwned(.programQueue, in: bridgeMode) else { break }
            state.program.items = items
            if let currentID = state.program.currentID,
               !items.contains(where: { $0.id == currentID }),
               state.program.currentDetachedItem?.id != currentID {
                state.program.currentID = nil
            }

        case .mediaLoaded(let url, let generation):
            guard generation == state.media.generation else { break }
            state.media.loadedURL = url
            state.media.didPlayToEnd = false

        case .mediaPlaybackChanged(let isPlaying, let generation):
            guard generation == state.media.generation else { break }
            state.media.isPlaying = isPlaying
            state.audio.routingContext.isMediaPlaying = isPlaying
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .mediaPlaybackChanged))

        case .mediaReachedEnd(let generation):
            guard generation == state.media.generation else { break }
            state.media.isPlaying = false
            state.media.didPlayToEnd = true
            state.audio.routingContext.isMediaPlaying = false
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .mediaPlaybackChanged))

        case .mediaSeekCompleted(let time, let generation):
            guard generation == state.media.generation else { break }
            state.media.currentTime = max(0, time)

        case .facadeCurrentProgramChanged(let id):
            state.program.currentID = id
            if let id, state.program.items.contains(where: { $0.id == id }) {
                state.program.currentDetachedItem = nil
            } else if state.program.currentDetachedItem?.id != id {
                state.program.currentDetachedItem = nil
            }
            state.program.currentSwitchedAt = id == nil ? nil : environment.now
            state.audio.routingContext.isCurrentProgramMediaSource = state.program.effectiveCurrentItem?.sourceKind == .media
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .programChanged))

        case .facadeAudioInputsChanged(let snapshot):
            applyAudioFacadeSnapshot(
                snapshot,
                to: &state,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .bgmPrepared(let id, let generation):
            guard generation == state.bgm.generation, id == state.bgm.currentID else { break }

        case .bgmPlaybackChanged(let isPlaying, let generation):
            guard generation == state.bgm.generation else { break }
            state.bgm.isPlaying = isPlaying
            state.audio.routingContext.isBGMPlaying = isPlaying
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .bgmPlaybackChanged))

        case .bgmReachedEnd(let generation):
            guard generation == state.bgm.generation else { break }
            reduceBGMReachedEnd(
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .bgmFailed(let reason, let generation):
            guard generation == state.bgm.generation else { break }
            state.bgm.generation += 1
            state.bgm.isPlaying = false
            state.audio.routingContext.isBGMPlaying = false
            if canGenerateReducerSupport(in: bridgeMode) {
                state.support.record(kind: .bgmPlaybackFailed, detail: "reason=\(reason)", at: environment.now)
            }
            effects += [
                .stopBGM(fade: 0, generation: state.bgm.generation),
                .stopBGMTimer(generation: state.bgm.generation)
            ]
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .bgmPlaybackChanged))

        case .bgmProgressUpdated(let time, let duration, let generation):
            guard generation == state.bgm.generation else { break }
            state.bgm.currentTime = max(0, time)
            state.bgm.duration = duration
            if let duration, duration > 0 {
                state.bgm.progress = min(max(time / duration, 0), 1)
            }

        case .panicFadeCompleted:
            break

        case .projectionStartFailed(let reason):
            guard isRuntimeOwned(.projection, in: bridgeMode) else { break }
            state.projection.isBroadcasting = false
            switch reason {
            case .noTargetScreen, .externalDisplayUnavailable:
                state.projection.hasExternalDisplay = false
                state.projection.safetyNotice = "未检测到外接屏幕，未开始投射"
            }

        case .projectionExternalDisplayLost:
            let wasBroadcasting = state.projection.isBroadcasting
            state.projection.isBroadcasting = false
            state.projection.hasExternalDisplay = false
            if wasBroadcasting {
                state.projection.safetyNotice = "副屏已断开，投射已停止"
            }
            guard wasBroadcasting else { break }
            if state.projection.lastDisplayLostAt == nil {
                state.projection.lastDisplayLostAt = environment.now
                if canGenerateReducerSupport(in: bridgeMode) {
                    state.support.record(kind: .projectionLost, detail: "state=displayLost", at: environment.now)
                }
            }
            effects.append(.stopProjection)

        case .projectionExternalDisplayAvailable:
            state.projection.hasExternalDisplay = true
            state.projection.safetyNotice = nil
            state.projection.lastDisplayLostAt = nil

        case .projectionExternalDisplayUnavailable:
            let wasBroadcasting = state.projection.isBroadcasting
            state.projection.isBroadcasting = false
            state.projection.hasExternalDisplay = false
            if wasBroadcasting {
                state.projection.safetyNotice = "副屏已断开，投射已停止"
                if state.projection.lastDisplayLostAt == nil {
                    state.projection.lastDisplayLostAt = environment.now
                }
                effects.append(.stopProjection)
            } else {
                state.projection.lastDisplayLostAt = nil
            }

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

    private static func reduceSelectedProgram(
        _ item: ProgramItem,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        now: Date,
        speakerModeDuckedRatio: Float
    ) {
        state.program.currentID = item.id
        state.program.currentDetachedItem = state.program.items.contains { $0.id == item.id } ? nil : item
        state.program.currentSwitchedAt = now

        if item.sourceKind == .media, let url = item.sourceURL {
            state.media.generation += 1
            state.media.loadedURL = url
            state.media.isPlaying = !state.panic.isActive
            state.media.didPlayToEnd = false
            state.media.currentTime = 0
            effects.append(.setMediaVolume(0, fade: 0, generation: state.media.generation))
            effects.append(.loadMedia(url, generation: state.media.generation))
            if !state.panic.isActive {
                effects.append(.playMedia(generation: state.media.generation))
            }
        } else {
            if state.media.loadedURL != nil || state.media.isPlaying {
                state.media.generation += 1
                state.media.isPlaying = false
                state.media.didPlayToEnd = false
                effects.append(.stopMedia(generation: state.media.generation))
            }
            state.media.loadedURL = nil
        }

        syncAudioRoutingContextFromMirrorState(&state)
        recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .programChanged))
    }

    private static func selectedProgramItem(_ id: UUID, in state: LiveRuntimeState) -> ProgramItem? {
        if let item = state.program.items.first(where: { $0.id == id }) {
            return item
        }
        if state.program.currentDetachedItem?.id == id {
            return state.program.currentDetachedItem
        }
        return nil
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

    private static func reducePanicToggle(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        now: Date,
        canWriteSupport: Bool,
        speakerModeDuckedRatio: Float
    ) {
        if state.panic.isActive {
            let snapshot = state.panic.snapshot
            state.panic.generation += 1
            state.panic.isActive = false
            state.panic.snapshot = nil

            if snapshot?.wasMediaPlaying == true,
               snapshot?.currentProgramID == state.program.currentID,
               state.program.effectiveCurrentItem?.sourceKind == .media {
                state.media.isPlaying = true
                effects.append(.playMedia(generation: state.media.generation))
            }

            if snapshot?.wasBGMPlaying == true,
               snapshot?.currentBGMID == state.bgm.currentID {
                state.bgm.isPlaying = true
                effects.append(.playBGM(generation: state.bgm.generation))
            }
        } else {
            state.panic.generation += 1
            state.panic.snapshot = PanicPlaybackSnapshot(
                currentProgramID: state.program.currentID,
                wasMediaPlaying: state.media.isPlaying && state.program.effectiveCurrentItem?.sourceKind == .media,
                currentBGMID: state.bgm.currentID,
                wasBGMPlaying: state.bgm.isPlaying
            )
            state.panic.isActive = true
            if state.panic.snapshot?.wasMediaPlaying == true {
                state.media.isPlaying = false
                effects.append(.pauseMedia(generation: state.media.generation))
            }
            if state.panic.snapshot?.wasBGMPlaying == true {
                state.bgm.isPlaying = false
                effects.append(.pauseBGM(generation: state.bgm.generation))
            }
            if canWriteSupport {
                state.support.record(kind: .panicModeChanged, detail: "isOn=true", at: now)
            }
        }
        syncAudioRoutingContextFromMirrorState(&state)
        recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .panicChanged))
    }

    private static func selectAdjacentBGM(
        offset: Int,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        guard let categoryItems = currentCategoryBGMItems(in: state),
              let currentID = state.bgm.currentID,
              let index = categoryItems.firstIndex(where: { $0.id == currentID }),
              !categoryItems.isEmpty
        else { return }
        let nextIndex = (index + offset + categoryItems.count) % categoryItems.count
        let nextItem = categoryItems[nextIndex]
        state.bgm.generation += 1
        state.bgm.currentID = nextItem.id
        state.bgm.isPlaying = true
        state.bgm.progress = 0
        state.bgm.currentTime = 0
        state.bgm.duration = nil
        effects += [
            .prepareBGM(nextItem, generation: state.bgm.generation),
            .playBGM(generation: state.bgm.generation),
            .startBGMTimer(generation: state.bgm.generation),
            .applyAudioRouting(reason: .bgmPlaybackChanged)
        ]
        syncAudioRoutingContextFromMirrorState(&state)
        recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
    }

    private static func reduceBGMReachedEnd(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        guard !state.panic.isActive else {
            stopFinishedBGM(
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: speakerModeDuckedRatio
            )
            return
        }

        guard let categoryItems = currentCategoryBGMItems(in: state),
              let currentID = state.bgm.currentID,
              let index = categoryItems.firstIndex(where: { $0.id == currentID })
        else {
            stopFinishedBGM(
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: speakerModeDuckedRatio
            )
            return
        }

        switch state.bgm.playMode {
        case .loopOne:
            restartBGM(
                categoryItems[index],
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: speakerModeDuckedRatio
            )
        case .loopAll:
            let nextIndex = (index + 1) % categoryItems.count
            restartBGM(
                categoryItems[nextIndex],
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: speakerModeDuckedRatio
            )
        case .sequential:
            if index < categoryItems.count - 1 {
                restartBGM(
                    categoryItems[index + 1],
                    state: &state,
                    effects: &effects,
                    speakerModeDuckedRatio: speakerModeDuckedRatio
                )
            } else {
                stopFinishedBGM(
                    state: &state,
                    effects: &effects,
                    speakerModeDuckedRatio: speakerModeDuckedRatio
                )
            }
        }
    }

    private static func currentCategoryBGMItems(in state: LiveRuntimeState) -> [BGMItem]? {
        guard let currentID = state.bgm.currentID,
              let currentItem = state.bgm.items.first(where: { $0.id == currentID })
        else { return nil }
        return state.bgm.items.filter { $0.category == currentItem.category }
    }

    private static func restartBGM(
        _ item: BGMItem,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        state.bgm.generation += 1
        state.bgm.currentID = item.id
        state.bgm.isPlaying = true
        state.bgm.progress = 0
        state.bgm.currentTime = 0
        state.bgm.duration = nil
        effects += [
            .prepareBGM(item, generation: state.bgm.generation),
            .playBGM(generation: state.bgm.generation),
            .startBGMTimer(generation: state.bgm.generation),
            .applyAudioRouting(reason: .bgmPlaybackChanged)
        ]
        syncAudioRoutingContextFromMirrorState(&state)
        recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
    }

    private static func stopFinishedBGM(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        speakerModeDuckedRatio: Float
    ) {
        state.bgm.generation += 1
        state.bgm.isPlaying = false
        state.bgm.progress = 0
        state.bgm.currentTime = 0
        state.bgm.duration = nil
        effects += [
            .stopBGM(fade: 0, generation: state.bgm.generation),
            .stopBGMTimer(generation: state.bgm.generation)
        ]
        syncAudioRoutingContextFromMirrorState(&state)
        recalculateAudio(&state, speakerModeDuckedRatio: speakerModeDuckedRatio)
        effects.append(.applyAudioRouting(reason: .bgmPlaybackChanged))
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

    private static func recalculateAudio(
        _ state: inout LiveRuntimeState,
        speakerModeDuckedRatio: Float = AudioRoutingDefaults.speakerModeDuckedRatio
    ) {
        initializeAudioRoutingContextIfNeeded(&state)
        let context = state.audio.routingContext
        let output = AudioRoutingEngine.output(
            for: AudioRoutingInput(
                masterVolume: state.audio.masterVolume,
                mediaVolume: state.audio.mediaVolume,
                bgmVolume: state.audio.bgmVolume,
                audioStrategy: state.audio.strategy,
                isCurrentProgramMediaSource: context.isCurrentProgramMediaSource,
                isMediaPlaying: context.isMediaPlaying,
                isBGMAudioTakeoverActive: state.audio.isBGMTakeoverActive,
                isSpeakerMode: state.audio.isSpeakerMode,
                isPanicMode: context.isPanicMode,
                isMasterMuted: state.audio.isMasterMuted,
                isMediaMuted: state.audio.isMediaMuted,
                isBGMMuted: state.audio.isBGMMuted,
                speakerModeDuckedRatio: speakerModeDuckedRatio
            )
        )
        state.audio.effectiveMedia = output.media
        state.audio.effectiveBGM = output.bgm
    }

    private static func initializeAudioRoutingContextIfNeeded(_ state: inout LiveRuntimeState) {
        guard state.audio.routingContext == AudioRoutingContext(),
              state.program.effectiveCurrentItem?.sourceKind == .media
                || state.media.isPlaying
                || state.bgm.isPlaying
                || state.panic.isActive
        else { return }
        syncAudioRoutingContextFromMirrorState(&state)
    }

    private static func syncAudioRoutingContextFromMirrorState(_ state: inout LiveRuntimeState) {
        state.audio.routingContext = AudioRoutingContext(
            isCurrentProgramMediaSource: state.program.effectiveCurrentItem?.sourceKind == .media,
            isMediaPlaying: state.media.isPlaying,
            isBGMPlaying: state.bgm.isPlaying,
            isPanicMode: state.panic.isActive
        )
    }

    private static func applyAudioFacadeSnapshot(
        _ snapshot: AudioFacadeSnapshot,
        to state: inout LiveRuntimeState,
        speakerModeDuckedRatio: Float
    ) {
        state.audio.masterVolume = min(max(snapshot.masterVolume, 0), 1)
        state.audio.mediaVolume = min(max(snapshot.mediaVolume, 0), 1)
        state.audio.bgmVolume = min(max(snapshot.bgmVolume, 0), 1)
        state.audio.strategy = snapshot.strategy
        state.audio.isMasterMuted = snapshot.isMasterMuted
        state.audio.isMediaMuted = snapshot.isMediaMuted
        state.audio.isBGMMuted = snapshot.isBGMMuted
        state.audio.isSpeakerMode = snapshot.isSpeakerMode
        state.audio.isBGMTakeoverActive = snapshot.isBGMTakeoverActive
        state.audio.routingContext = AudioRoutingContext(
            isCurrentProgramMediaSource: snapshot.isCurrentProgramMediaSource,
            isMediaPlaying: snapshot.isMediaPlaying,
            isBGMPlaying: snapshot.isBGMPlaying,
            isPanicMode: snapshot.isPanicMode
        )

        let context = state.audio.routingContext
        let output = AudioRoutingEngine.output(
            for: AudioRoutingInput(
                masterVolume: state.audio.masterVolume,
                mediaVolume: state.audio.mediaVolume,
                bgmVolume: state.audio.bgmVolume,
                audioStrategy: state.audio.strategy,
                isCurrentProgramMediaSource: context.isCurrentProgramMediaSource,
                isMediaPlaying: context.isMediaPlaying,
                isBGMAudioTakeoverActive: state.audio.isBGMTakeoverActive,
                isSpeakerMode: state.audio.isSpeakerMode,
                isPanicMode: context.isPanicMode,
                isMasterMuted: state.audio.isMasterMuted,
                isMediaMuted: state.audio.isMediaMuted,
                isBGMMuted: state.audio.isBGMMuted,
                speakerModeDuckedRatio: speakerModeDuckedRatio
            )
        )
        state.audio.effectiveMedia = output.media
        state.audio.effectiveBGM = output.bgm
    }

    private static func isEffectAllowed(_ effect: LiveRuntimeEffect, in bridgeMode: LiveRuntimeBridgeMode) -> Bool {
        if bridgeMode == .fullRuntime { return true }
        if bridgeMode == .recordingOnly { return false }

        return bridgeMode.owns(effect.requiredBridgeDomain)
    }

    private static func isRuntimeOwned(_ domain: LiveRuntimeDomain, in bridgeMode: LiveRuntimeBridgeMode) -> Bool {
        bridgeMode.owns(domain)
    }

    private static func moveProgramItems(_ items: inout [ProgramItem], fromOffsets: [Int], toOffset: Int) {
        let validOffsets = Array(Set(fromOffsets))
            .filter { items.indices.contains($0) }
            .sorted()
        guard !validOffsets.isEmpty else { return }

        let movingItems = validOffsets.map { items[$0] }
        for index in validOffsets.reversed() {
            items.remove(at: index)
        }

        let removedBeforeDestination = validOffsets.filter { $0 < toOffset }.count
        let insertionIndex = min(max(0, toOffset - removedBeforeDestination), items.count)
        items.insert(contentsOf: movingItems, at: insertionIndex)
    }

    private static func canGenerateReducerSupport(in bridgeMode: LiveRuntimeBridgeMode) -> Bool {
        bridgeMode == .fullRuntime
    }
}
