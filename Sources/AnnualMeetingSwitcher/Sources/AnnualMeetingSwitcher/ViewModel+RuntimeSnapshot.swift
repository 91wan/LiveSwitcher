import Foundation

@MainActor
extension SwitcherViewModel {
    func syncRuntimeStateFromFacade(clearActionLog: Bool) {
        syncRuntimeStateFromFacade(clearActionLog: clearActionLog, dispatchAudioInputsChanged: true)
    }

    func syncRuntimeStateFromFacade(
        clearActionLog: Bool,
        dispatchAudioInputsChanged: Bool
    ) {
        let snapshot = makeRuntimeStateSnapshot()
        let audioInputsChanged = dispatchAudioInputsChanged && !runtimeAudioInputsMatch(runtime.state, snapshot)
        let audioSnapshot = audioFacadeSnapshot()
        runtime.replaceStateForFacadeSync(snapshot, clearActionLog: clearActionLog)
        if audioInputsChanged {
            runtime.dispatch(.facadeAudioInputsChanged(audioSnapshot))
        }
    }

    private func runtimeAudioInputsMatch(_ lhs: LiveRuntimeState, _ rhs: LiveRuntimeState) -> Bool {
        lhs.audio.masterVolume == rhs.audio.masterVolume
            && lhs.audio.mediaVolume == rhs.audio.mediaVolume
            && lhs.audio.bgmVolume == rhs.audio.bgmVolume
            && lhs.audio.strategy == rhs.audio.strategy
            && lhs.audio.isMasterMuted == rhs.audio.isMasterMuted
            && lhs.audio.isMediaMuted == rhs.audio.isMediaMuted
            && lhs.audio.isBGMMuted == rhs.audio.isBGMMuted
            && lhs.audio.isSpeakerMode == rhs.audio.isSpeakerMode
            && lhs.audio.isBGMTakeoverActive == rhs.audio.isBGMTakeoverActive
            && lhs.audio.routingContext == rhs.audio.routingContext
    }

    private func audioFacadeSnapshot() -> AudioFacadeSnapshot {
        AudioFacadeSnapshot(
            masterVolume: masterVolume,
            mediaVolume: mediaVolume,
            bgmVolume: bgmVolume,
            strategy: audioStrategy,
            isMasterMuted: isMasterAudioMuted,
            isMediaMuted: isMediaAudioMuted,
            isBGMMuted: isBGMAudioMuted,
            isSpeakerMode: isSpeakerMode,
            isBGMTakeoverActive: isBGMAudioTakeoverActive,
            isPanicMode: isPanicMode,
            isCurrentProgramMediaSource: currentProgramIsMediaSource,
            isMediaPlaying: avCoordinator.isPlaying,
            isBGMPlaying: runtime.bridgeMode.owns(.bgm) ? runtime.state.bgm.isPlaying : isBGMPlaying
        )
    }

    private func makeRuntimeStateSnapshot() -> LiveRuntimeState {
        var state = runtime.state
        state.mode = consoleMode
        syncProgramQueueIntoRuntimeSnapshot(&state)
        let queueItemsForCurrentLookup = runtime.bridgeMode.owns(.programQueue)
            ? state.program.items
            : programItems
        if let currentProgramItem,
           !queueItemsForCurrentLookup.contains(where: { $0.id == currentProgramItem.id }) {
            state.program.currentDetachedItem = currentProgramItem
        } else {
            state.program.currentDetachedItem = nil
        }
        state.program.currentID = currentProgramItem?.id
        state.program.currentSwitchedAt = currentProgramSwitchedAt

        state.media.loadedURL = avCoordinator.currentURL
        state.media.isPlaying = avCoordinator.isPlaying
        state.media.currentTime = avCoordinator.currentTime
        state.media.duration = avCoordinator.duration

        syncBGMLibraryIntoRuntimeSnapshot(&state)

        state.audio.masterVolume = masterVolume
        state.audio.mediaVolume = mediaVolume
        state.audio.bgmVolume = bgmVolume
        state.audio.strategy = audioStrategy
        state.audio.isMasterMuted = isMasterAudioMuted
        state.audio.isMediaMuted = isMediaAudioMuted
        state.audio.isBGMMuted = isBGMAudioMuted
        state.audio.isSpeakerMode = isSpeakerMode
        state.audio.isBGMTakeoverActive = isBGMAudioTakeoverActive
        state.audio.routingContext = AudioRoutingContext(
            isCurrentProgramMediaSource: currentProgramIsMediaSource,
            isMediaPlaying: avCoordinator.isPlaying,
            isBGMPlaying: runtime.bridgeMode.owns(.bgm) ? runtime.state.bgm.isPlaying : isBGMPlaying,
            isPanicMode: isPanicMode
        )

        state.panic.isActive = isPanicMode
        state.panic.snapshot = panicPlaybackSnapshot

        syncPPTFacadeIntoRuntimeSnapshot(&state)
        state.preferences.themeOverride = themeOverride
        state.preferences.activeWallpaperURL = activeWallpaperURL
        state.preferences.cornerLogoURL = cornerLogoURL
        state.preferences.autoPlayNextVideoOnEnd = autoPlayNextVideoOnEnd
        state.preferences.autoAdvanceAtScheduledTime = autoAdvanceAtScheduledTime
        state.preferences.showAgendaTimeline = showAgendaTimeline
        state.preferences.cornerLogoPosition = cornerLogoPosition

        syncProjectionAvailabilityIntoRuntimeSnapshot(&state)

        syncAutomationNoticeIntoRuntimeSnapshot(&state)
        syncSupportIntoRuntimeSnapshot(&state)
        return state
    }

    private func syncProgramQueueIntoRuntimeSnapshot(_ state: inout LiveRuntimeState) {
        guard !runtime.bridgeMode.owns(.programQueue) else {
            state.program.items = runtime.state.program.items
            return
        }

        state.program.items = programItems
    }

    private func syncSupportIntoRuntimeSnapshot(_ state: inout LiveRuntimeState) {
        guard !runtime.bridgeMode.owns(.support) else {
            state.support = runtime.state.support
            return
        }

        state.support.events = supportEvents
    }

    private func syncAutomationNoticeIntoRuntimeSnapshot(_ state: inout LiveRuntimeState) {
        guard !runtime.bridgeMode.owns(.automationNotice) else {
            state.automation = runtime.state.automation
            return
        }

        state.automation.notice = automationRuntimeNotice
    }

    private func syncProjectionAvailabilityIntoRuntimeSnapshot(_ state: inout LiveRuntimeState) {
        state.projection.hasExternalDisplay = isExternalDisplayAvailable

        guard runtime.bridgeMode.owns(.projection) else {
            state.projection.isBroadcasting = isBroadcasting
            state.projection.safetyNotice = broadcastSafetyNotice
            return
        }

        state.projection.isBroadcasting = runtime.state.projection.isBroadcasting
        state.projection.safetyNotice = runtime.state.projection.safetyNotice
        state.projection.lastDisplayLostAt = runtime.state.projection.lastDisplayLostAt
    }

    private func syncPPTFacadeIntoRuntimeSnapshot(_ state: inout LiveRuntimeState) {
        guard !runtime.bridgeMode.owns(.ppt) else {
            state.ppt = runtime.state.ppt
            return
        }

        state.ppt.isRequested = isPageInterceptEnabled
        state.ppt.isEventTapActive = isPageInterceptEventTapActiveForRuntimeSnapshot
    }

    private func syncBGMLibraryIntoRuntimeSnapshot(_ state: inout LiveRuntimeState) {
        state.bgm.items = runtimeBGMItemsForSnapshot()
        state.bgm.playMode = bgmPlayMode

        guard !runtime.bridgeMode.owns(.bgm) else { return }

        state.bgm.currentID = currentBGMItem?.id
        state.bgm.isPlaying = isBGMPlaying
        state.bgm.progress = bgmProgress
        state.bgm.currentTime = bgmCurrentTime
        state.bgm.duration = bgmDuration
    }
}
