import Foundation

struct LiveRuntimeMutation: Equatable {
    var state: LiveRuntimeState
    var effects: [LiveRuntimeEffect]
}

enum LiveRuntimeReducer {
    static func reduce(
        state: LiveRuntimeState,
        action: LiveRuntimeAction,
        environment: LiveRuntimeEnvironment = LiveRuntimeEnvironment()
    ) -> LiveRuntimeMutation {
        var state = state
        var effects: [LiveRuntimeEffect] = []

        switch action {
        case .operatorSelectedProgram(let id):
            reduceSelectedProgram(id, state: &state, effects: &effects, now: environment.now)

        case .operatorToggledMediaPlayback:
            guard !state.media.didPlayToEnd else { break }
            state.media.isPlaying.toggle()
            effects.append(state.media.isPlaying ? .playMedia(generation: state.media.generation) : .pauseMedia(generation: state.media.generation))
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .mediaPlaybackChanged))

        case .operatorRestartedCurrentMedia:
            guard state.program.currentItem?.supportsSeeking == true else { break }
            state.media.didPlayToEnd = false
            state.media.currentTime = 0
            state.media.isPlaying = true
            effects.append(.restartMedia(generation: state.media.generation))
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .mediaPlaybackChanged))

        case .operatorSelectedAudioStrategy(let strategy):
            state.audio.strategy = strategy
            recalculateAudio(&state)
            effects += [
                .applyAudioRouting(reason: .strategyChanged),
                .savePersistentState
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
                .savePersistentState
            ]

        case .operatorSetSpeakerMode(let isEnabled):
            state.audio.isSpeakerMode = isEnabled
            recalculateAudio(&state)
            effects += [
                .applyAudioRouting(reason: .speakerChanged),
                .savePersistentState
            ]

        case .operatorToggledPanic:
            reducePanicToggle(state: &state, effects: &effects, now: environment.now)

        case .operatorSetPanic(let isActive):
            guard state.panic.isActive != isActive else { break }
            reducePanicToggle(state: &state, effects: &effects, now: environment.now)

        case .operatorSelectedBGM(let id):
            guard let item = state.bgm.items.first(where: { $0.id == id }) else { break }
            state.bgm.generation += 1
            state.bgm.currentID = id
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
            recalculateAudio(&state)

        case .operatorSelectedBGMPlayMode(let playMode):
            state.bgm.playMode = playMode
            effects.append(.savePersistentState)

        case .operatorStoppedBGM:
            state.bgm.generation += 1
            state.bgm.isPlaying = false
            effects += [
                .stopBGM(fade: 0.5, generation: state.bgm.generation),
                .stopBGMTimer(generation: state.bgm.generation),
                .applyAudioRouting(reason: .bgmPlaybackChanged)
            ]
            recalculateAudio(&state)

        case .operatorSelectedNextBGM:
            selectAdjacentBGM(offset: 1, state: &state, effects: &effects)

        case .operatorSelectedPreviousBGM:
            selectAdjacentBGM(offset: -1, state: &state, effects: &effects)

        case .operatorToggledPPTMode:
            if state.ppt.isRequested || state.ppt.isEventTapActive {
                state.ppt.isRequested = false
                state.ppt.isEventTapActive = false
                effects.append(.stopPPTEventTap(reason: .operatorDisabled))
                state.support.record(kind: .pageInterceptDisabled, detail: "source=runtime", at: environment.now)
            } else {
                state.ppt.isRequested = true
                state.ppt.lastFailureReason = nil
                effects.append(.startPPTEventTap)
            }

        case .operatorToggledProjection:
            if state.projection.isBroadcasting {
                state.projection.isBroadcasting = false
                effects += [.stopProjection, .hideOutputWindow]
                state.support.record(kind: .projectionStopped, detail: "source=runtime", at: environment.now)
            } else if state.projection.hasExternalDisplay {
                state.projection.isBroadcasting = true
                state.projection.safetyNotice = nil
                effects += [.startProjection, .showOutputWindow]
                state.support.record(kind: .projectionStarted, detail: "source=runtime", at: environment.now)
            } else {
                state.projection.safetyNotice = "No external display"
                state.support.record(kind: .projectionStartFailed, detail: "reason=noExternalDisplay", at: environment.now)
            }

        case .mediaLoaded(let url, let generation):
            guard generation == state.media.generation else { break }
            state.media.loadedURL = url
            state.media.didPlayToEnd = false

        case .mediaPlaybackChanged(let isPlaying, let generation):
            guard generation == state.media.generation else { break }
            state.media.isPlaying = isPlaying
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .mediaPlaybackChanged))

        case .mediaReachedEnd(let generation):
            guard generation == state.media.generation else { break }
            state.media.isPlaying = false
            state.media.didPlayToEnd = true
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .mediaPlaybackChanged))

        case .mediaSeekCompleted(let time, let generation):
            guard generation == state.media.generation else { break }
            state.media.currentTime = max(0, time)

        case .bgmPrepared(let id, let generation):
            guard generation == state.bgm.generation, id == state.bgm.currentID else { break }

        case .bgmPlaybackChanged(let isPlaying, let generation):
            guard generation == state.bgm.generation else { break }
            state.bgm.isPlaying = isPlaying
            recalculateAudio(&state)
            effects.append(.applyAudioRouting(reason: .bgmPlaybackChanged))

        case .bgmReachedEnd(let generation):
            guard generation == state.bgm.generation else { break }
            reduceBGMReachedEnd(state: &state, effects: &effects)

        case .bgmFailed(let reason, let generation):
            guard generation == state.bgm.generation else { break }
            state.bgm.isPlaying = false
            state.support.record(kind: .bgmPlaybackFailed, detail: "reason=\(reason)", at: environment.now)
            effects.append(.stopBGMTimer(generation: generation))
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

        case .projectionExternalDisplayLost:
            let wasBroadcasting = state.projection.isBroadcasting
            state.projection.isBroadcasting = false
            state.projection.hasExternalDisplay = false
            guard wasBroadcasting else { break }
            if state.projection.lastDisplayLostAt == nil {
                state.projection.lastDisplayLostAt = environment.now
                state.support.record(kind: .projectionLost, detail: "state=displayLost", at: environment.now)
            }
            effects.append(.stopProjection)

        case .projectionExternalDisplayAvailable:
            state.projection.hasExternalDisplay = true
            state.projection.safetyNotice = nil
            state.projection.lastDisplayLostAt = nil

        case .projectionExternalDisplayUnavailable:
            state.projection.hasExternalDisplay = false
            if !state.projection.isBroadcasting {
                state.projection.lastDisplayLostAt = nil
            }

        case .pptEventTapStarted:
            state.ppt.isRequested = true
            state.ppt.isEventTapActive = true
            state.ppt.lastFailureReason = nil
            state.support.record(kind: .pageInterceptEnabled, detail: "source=runtime", at: environment.now)

        case .pptEventTapFailed(let reason):
            state.ppt.isRequested = false
            state.ppt.isEventTapActive = false
            state.ppt.lastFailureReason = reason
            state.support.record(kind: .pageInterceptDisabled, detail: "reason=failed", at: environment.now)
            effects.append(.stopPPTEventTap(reason: .failed))

        case .pptEventTapStopped(let reason):
            state.ppt.isEventTapActive = false
            if reason != .programChanged {
                state.ppt.isRequested = false
            }

        case .automationFailed(let action, let sanitizedMessage):
            requestAutomationNotice(action: action, state: &state, effects: &effects, now: environment.now)
            state.support.record(
                kind: .appleScriptFailed,
                detail: "action=\(action),error=\(sanitizedMessage)",
                at: environment.now
            )

        case .automationNoticeRequested(let action):
            requestAutomationNotice(action: action, state: &state, effects: &effects, now: environment.now)

        case .automationNoticeExpired(let id):
            if state.automation.notice?.id == id {
                state.automation.notice = nil
            }

        case .automationNoticeDismissed:
            state.automation.notice = nil

        case .supportEventRecorded(let event):
            state.support.record(kind: event.kind, detail: event.detail, at: event.timestamp)
        }

        return LiveRuntimeMutation(state: state, effects: effects)
    }

    private static func reduceSelectedProgram(
        _ id: UUID,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        now: Date
    ) {
        guard let item = state.program.items.first(where: { $0.id == id }) else { return }
        let previousKind = state.program.currentItem?.sourceKind
        state.program.currentID = id
        state.program.currentSwitchedAt = now

        if previousKind?.supportsPresentationControl == true, !item.supportsPresentationControl {
            state.ppt.isEventTapActive = false
            effects.append(.stopPPTEventTap(reason: .programChanged))
        }

        if item.sourceKind == .media, let url = item.sourceURL {
            state.media.generation += 1
            state.media.loadedURL = url
            state.media.isPlaying = true
            state.media.didPlayToEnd = false
            state.media.currentTime = 0
            effects += [
                .loadMedia(url, generation: state.media.generation),
                .playMedia(generation: state.media.generation)
            ]
        } else {
            if state.media.loadedURL != nil || state.media.isPlaying {
                state.media.generation += 1
                state.media.isPlaying = false
                state.media.didPlayToEnd = false
                effects.append(.stopMedia(generation: state.media.generation))
            }
            state.media.loadedURL = nil
        }

        if item.supportsPresentationControl {
            state.ppt.isRequested = true
            effects.append(.startPPTEventTap)
        } else if previousKind?.supportsPresentationControl == true {
            state.ppt.isRequested = false
        }

        recalculateAudio(&state)
        effects.append(.applyAudioRouting(reason: .programChanged))
    }

    private static func reducePanicToggle(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        now: Date
    ) {
        if state.panic.isActive {
            let snapshot = state.panic.snapshot
            state.panic.generation += 1
            state.panic.isActive = false
            state.panic.snapshot = nil

            if snapshot?.wasMediaPlaying == true,
               snapshot?.currentProgramID == state.program.currentID,
               state.program.currentItem?.sourceKind == .media {
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
                wasMediaPlaying: state.media.isPlaying && state.program.currentItem?.sourceKind == .media,
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
            state.support.record(kind: .panicModeChanged, detail: "isOn=true", at: now)
        }
        recalculateAudio(&state)
        effects.append(.applyAudioRouting(reason: .panicChanged))
    }

    private static func selectAdjacentBGM(
        offset: Int,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        guard let currentID = state.bgm.currentID,
              let index = state.bgm.items.firstIndex(where: { $0.id == currentID }),
              !state.bgm.items.isEmpty
        else { return }
        let nextIndex = (index + offset + state.bgm.items.count) % state.bgm.items.count
        let nextItem = state.bgm.items[nextIndex]
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
        recalculateAudio(&state)
    }

    private static func reduceBGMReachedEnd(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        guard let currentID = state.bgm.currentID,
              let index = state.bgm.items.firstIndex(where: { $0.id == currentID })
        else {
            stopFinishedBGM(state: &state, effects: &effects)
            return
        }

        switch state.bgm.playMode {
        case .loopOne:
            restartBGM(state.bgm.items[index], state: &state, effects: &effects)
        case .loopAll:
            let nextIndex = (index + 1) % state.bgm.items.count
            restartBGM(state.bgm.items[nextIndex], state: &state, effects: &effects)
        case .sequential:
            if index < state.bgm.items.count - 1 {
                restartBGM(state.bgm.items[index + 1], state: &state, effects: &effects)
            } else {
                stopFinishedBGM(state: &state, effects: &effects)
            }
        }
    }

    private static func restartBGM(
        _ item: BGMItem,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
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
        recalculateAudio(&state)
    }

    private static func stopFinishedBGM(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        state.bgm.generation += 1
        state.bgm.isPlaying = false
        effects.append(.stopBGMTimer(generation: state.bgm.generation))
        recalculateAudio(&state)
        effects.append(.applyAudioRouting(reason: .bgmPlaybackChanged))
    }

    private static func requestAutomationNotice(
        action: String,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        now: Date
    ) {
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

    private static func recalculateAudio(_ state: inout LiveRuntimeState) {
        guard !state.panic.isActive else {
            state.audio.effectiveMedia = 0
            state.audio.effectiveBGM = 0
            return
        }

        let master = state.audio.isMasterMuted ? 0 : state.audio.masterVolume
        let media = state.audio.isMediaMuted || !state.media.isPlaying ? 0 : state.audio.mediaVolume
        let bgm = state.audio.isBGMMuted || !state.bgm.isPlaying ? 0 : state.audio.bgmVolume
        state.audio.effectiveMedia = Float(master * media)
        state.audio.effectiveBGM = Float(master * bgm)
    }
}
