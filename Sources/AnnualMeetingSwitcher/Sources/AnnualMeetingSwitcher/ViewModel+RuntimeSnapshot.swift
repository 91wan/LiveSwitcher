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
            masterVolume: runtimeBackedMasterVolumeForSnapshot,
            mediaVolume: runtimeBackedMediaVolumeForSnapshot,
            bgmVolume: runtimeBackedBGMVolumeForSnapshot,
            strategy: runtimeBackedAudioStrategyForSnapshot,
            isMasterMuted: runtimeBackedMasterMuteForSnapshot,
            isMediaMuted: runtimeBackedMediaMuteForSnapshot,
            isBGMMuted: runtimeBackedBGMMuteForSnapshot,
            isSpeakerMode: runtimeBackedSpeakerModeForSnapshot,
            isBGMTakeoverActive: runtimeBackedBGMTakeoverForSnapshot,
            isPanicMode: runtimeBackedPanicIsActiveForSnapshot,
            isCurrentProgramMediaSource: runtimeBackedCurrentProgramIsMediaSourceForSnapshot,
            isMediaPlaying: runtimeBackedMediaIsPlayingForSnapshot,
            isBGMPlaying: runtime.bridgeMode.owns(.bgm) ? runtime.state.bgm.isPlaying : isBGMPlaying
        )
    }

    private var runtimeBackedMasterVolumeForSnapshot: Double {
        runtime.bridgeMode.owns(.audio) ? runtime.state.audio.masterVolume : masterVolume
    }

    private var runtimeBackedMediaVolumeForSnapshot: Double {
        runtime.bridgeMode.owns(.audio) ? runtime.state.audio.mediaVolume : mediaVolume
    }

    private var runtimeBackedBGMVolumeForSnapshot: Double {
        runtime.bridgeMode.owns(.audio) ? runtime.state.audio.bgmVolume : bgmVolume
    }

    private var runtimeBackedAudioStrategyForSnapshot: AudioStrategy {
        runtime.bridgeMode.owns(.audio) ? runtime.state.audio.strategy : audioStrategy
    }

    private var runtimeBackedMasterMuteForSnapshot: Bool {
        runtime.bridgeMode.owns(.audio) ? runtime.state.audio.isMasterMuted : isMasterAudioMuted
    }

    private var runtimeBackedMediaMuteForSnapshot: Bool {
        runtime.bridgeMode.owns(.audio) ? runtime.state.audio.isMediaMuted : isMediaAudioMuted
    }

    private var runtimeBackedBGMMuteForSnapshot: Bool {
        runtime.bridgeMode.owns(.audio) ? runtime.state.audio.isBGMMuted : isBGMAudioMuted
    }

    private var runtimeBackedSpeakerModeForSnapshot: Bool {
        runtime.bridgeMode.owns(.audio) ? runtime.state.audio.isSpeakerMode : isSpeakerMode
    }

    private var runtimeBackedBGMTakeoverForSnapshot: Bool {
        runtime.bridgeMode.owns(.audio) ? runtime.state.audio.isBGMTakeoverActive : isBGMAudioTakeoverActive
    }

    private var runtimeBackedMediaIsPlayingForSnapshot: Bool {
        runtime.bridgeMode.owns(.media)
            ? runtime.state.media.isPlaying
            : avCoordinator.isPlaying
    }

    private func runtimeBackedMediaIsPlayingForSnapshot(_ state: LiveRuntimeState) -> Bool {
        runtime.bridgeMode.owns(.media)
            ? state.media.isPlaying
            : avCoordinator.isPlaying
    }

    private var runtimeBackedCurrentProgramIsMediaSourceForSnapshot: Bool {
        runtime.bridgeMode.owns(.programSelection)
            ? runtime.state.program.effectiveCurrentItem?.sourceKind == .media
            : currentProgramIsMediaSource
    }

    private func runtimeBackedCurrentProgramIsMediaSourceForSnapshot(_ state: LiveRuntimeState) -> Bool {
        runtime.bridgeMode.owns(.programSelection)
            ? state.program.effectiveCurrentItem?.sourceKind == .media
            : currentProgramIsMediaSource
    }

    private var runtimeBackedPanicIsActiveForSnapshot: Bool {
        runtime.bridgeMode.owns(.panic)
            ? runtime.state.panic.isActive
            : isPanicMode
    }

    private func makeRuntimeStateSnapshot() -> LiveRuntimeState {
        var state = runtime.state
        syncPreferencesIntoRuntimeSnapshot(&state)
        syncProgramQueueIntoRuntimeSnapshot(&state)
        syncCurrentProgramIntoRuntimeSnapshot(&state)
        syncMediaIntoRuntimeSnapshot(&state)

        syncBGMIntoRuntimeSnapshot(&state)

        syncAudioIntoRuntimeSnapshot(&state)

        syncPanicIntoRuntimeSnapshot(&state)

        syncPPTFacadeIntoRuntimeSnapshot(&state)

        syncProjectionIntoRuntimeSnapshot(&state)

        syncAutomationNoticeIntoRuntimeSnapshot(&state)
        syncSupportIntoRuntimeSnapshot(&state)
        return state
    }

    private func syncAudioIntoRuntimeSnapshot(_ state: inout LiveRuntimeState) {
        let routingContext = AudioRoutingContext(
            isCurrentProgramMediaSource: runtimeBackedCurrentProgramIsMediaSourceForSnapshot(state),
            isMediaPlaying: runtimeBackedMediaIsPlayingForSnapshot(state),
            isBGMPlaying: runtime.bridgeMode.owns(.bgm) ? runtime.state.bgm.isPlaying : isBGMPlaying,
            isPanicMode: runtimeBackedPanicIsActiveForSnapshot
        )

        if runtime.bridgeMode.owns(.audio) {
            let runtimeAudio = runtime.state.audio
            state.audio = runtimeAudio
            state.audio.routingContext = routingContext
            return
        }

        state.audio.masterVolume = masterVolume
        state.audio.mediaVolume = mediaVolume
        state.audio.bgmVolume = bgmVolume
        state.audio.strategy = audioStrategy
        state.audio.isMasterMuted = isMasterAudioMuted
        state.audio.isMediaMuted = isMediaAudioMuted
        state.audio.isBGMMuted = isBGMAudioMuted
        state.audio.isSpeakerMode = isSpeakerMode
        state.audio.isBGMTakeoverActive = isBGMAudioTakeoverActive
        state.audio.routingContext = routingContext
    }

    private func syncPreferencesIntoRuntimeSnapshot(_ state: inout LiveRuntimeState) {
        guard !runtime.bridgeMode.owns(.persistence) else {
            state.mode = runtime.state.mode
            state.preferences = runtime.state.preferences
            return
        }

        state.mode = consoleMode
        state.preferences.themeOverride = themeOverride
        state.preferences.activeWallpaperURL = activeWallpaperURL
        state.preferences.cornerLogoURL = cornerLogoURL
        state.preferences.autoPlayNextVideoOnEnd = autoPlayNextVideoOnEnd
        state.preferences.autoAdvanceAtScheduledTime = autoAdvanceAtScheduledTime
        state.preferences.showAgendaTimeline = showAgendaTimeline
        state.preferences.cornerLogoPosition = cornerLogoPosition
    }

    private func syncProgramQueueIntoRuntimeSnapshot(_ state: inout LiveRuntimeState) {
        guard !runtime.bridgeMode.owns(.programQueue) else {
            state.program.items = runtime.state.program.items
            return
        }

        state.program.items = programItems
    }

    private func syncCurrentProgramIntoRuntimeSnapshot(_ state: inout LiveRuntimeState) {
        guard !runtime.bridgeMode.owns(.programSelection) else {
            state.program.currentID = runtime.state.program.currentID
            state.program.currentDetachedItem = runtime.state.program.currentDetachedItem
            state.program.currentSwitchedAt = runtime.state.program.currentSwitchedAt
            return
        }

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
    }

    private func syncMediaIntoRuntimeSnapshot(_ state: inout LiveRuntimeState) {
        guard !runtime.bridgeMode.owns(.media) else {
            state.media = runtime.state.media
            return
        }

        state.media.loadedURL = avCoordinator.currentURL
        state.media.isPlaying = avCoordinator.isPlaying
        state.media.currentTime = avCoordinator.currentTime
        state.media.duration = avCoordinator.duration
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

    private func syncPanicIntoRuntimeSnapshot(_ state: inout LiveRuntimeState) {
        guard !runtime.bridgeMode.owns(.panic) else {
            state.panic = runtime.state.panic
            return
        }

        state.panic.isActive = isPanicMode
        state.panic.snapshot = panicPlaybackSnapshot
    }

    private func syncProjectionIntoRuntimeSnapshot(_ state: inout LiveRuntimeState) {
        guard !runtime.bridgeMode.owns(.projection) else {
            state.projection = runtime.state.projection
            return
        }

        state.projection.hasExternalDisplay = isExternalDisplayAvailable
        state.projection.isBroadcasting = isBroadcasting
        state.projection.safetyNotice = broadcastSafetyNotice
    }

    private func syncPPTFacadeIntoRuntimeSnapshot(_ state: inout LiveRuntimeState) {
        guard !runtime.bridgeMode.owns(.ppt) else {
            state.ppt = runtime.state.ppt
            return
        }

        state.ppt.isRequested = isPageInterceptEnabled
        state.ppt.isEventTapActive = isPageInterceptEventTapActiveForRuntimeSnapshot
    }

    private func syncBGMIntoRuntimeSnapshot(_ state: inout LiveRuntimeState) {
        let items = runtimeBGMItemsForSnapshot()

        guard !runtime.bridgeMode.owns(.bgm) else {
            let runtimeBGM = runtime.state.bgm
            state.bgm = runtimeBGM
            state.bgm.items = items
            return
        }

        state.bgm.items = items
        state.bgm.playMode = bgmPlayMode
        state.bgm.currentID = currentBGMItem?.id
        if isBGMPlaying {
            state.bgm.phase = .playing
        } else if currentBGMItem != nil {
            state.bgm.phase = .selected
        } else {
            state.bgm.phase = .idle
        }
        state.bgm.progress = bgmProgress
        state.bgm.currentTime = bgmCurrentTime
        state.bgm.duration = bgmDuration
    }
}
