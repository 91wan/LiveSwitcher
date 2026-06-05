import Foundation

private struct LiveMasterMeterCandidate {
    let realtimeDB: Float
    let effectiveVolume: Float

    var postFaderDB: Double {
        Double(realtimeDB) + 20 * log10(Double(effectiveVolume))
    }
}

@MainActor
extension SwitcherViewModel {
    // MARK: - Audio Routing

    func applyMasterVolume() {
        applyCurrentRuntimeAudioRouting(reason: .operatorFaderChanged)
    }

    func applyBGMVolume() {
        applyCurrentRuntimeAudioRouting(reason: .operatorFaderChanged)
    }

    func effectiveMediaOutputVolume() -> Float {
        runtime.state.audio.effectiveMedia
    }

    func effectiveBGMOutputVolume() -> Float {
        runtime.state.audio.effectiveBGM
    }

    func liveMasterMeterRealtimeDB() -> Float? {
        liveMasterMeterRealtimeCandidate()?.realtimeDB
    }

    func liveMasterMeterFallbackVolume() -> Float {
        if let candidate = liveMasterMeterRealtimeCandidate() {
            return candidate.effectiveVolume
        }

        return max(effectiveMediaOutputVolume(), effectiveBGMOutputVolume())
    }

    private func liveMasterMeterRealtimeCandidate() -> LiveMasterMeterCandidate? {
        let effectiveMedia = effectiveMediaOutputVolume()
        let effectiveBGM = (!isBGMPlaying && currentBGMItem != nil) ? 0 : effectiveBGMOutputVolume()
        guard !isPanicMode, !isMasterAudioMuted else {
            return nil
        }

        var candidates: [LiveMasterMeterCandidate] = []
        if avCoordinator.isPlaying,
           !isMediaAudioMuted,
           effectiveMedia > 0,
           let mediaDB = avCoordinator.realtimeLevelDB,
           mediaDB.isFinite {
            candidates.append(LiveMasterMeterCandidate(realtimeDB: mediaDB, effectiveVolume: effectiveMedia))
        }
        if isBGMPlaying,
           !isBGMAudioMuted,
           effectiveBGM > 0,
           let bgmDB = bgmRealtimeLevelDB,
           bgmDB.isFinite {
            candidates.append(LiveMasterMeterCandidate(realtimeDB: bgmDB, effectiveVolume: effectiveBGM))
        }

        return candidates.max { lhs, rhs in
            lhs.postFaderDB < rhs.postFaderDB
        }
    }

    private var legacyAudioRoutingOutputForSnapshotOnly: AudioRoutingOutput {
        AudioRoutingEngine.output(
            for: AudioRoutingInput(
                masterVolume: masterVolume,
                mediaVolume: mediaVolume,
                bgmVolume: bgmVolume,
                audioStrategy: audioStrategy,
                isCurrentProgramMediaSource: currentProgramIsMediaSource,
                isMediaPlaying: avCoordinator.isPlaying,
                isBGMAudioTakeoverActive: isBGMAudioTakeoverActive,
                isSpeakerMode: isSpeakerMode,
                isPanicMode: isPanicMode,
                isMasterMuted: isMasterAudioMuted,
                isMediaMuted: isMediaAudioMuted,
                isBGMMuted: isBGMAudioMuted,
                speakerModeDuckedRatio: runtimeSpeakerModeDuckedRatio
            )
        )
    }

    func applyAudioRouting(
        mediaFadeDuration: Double? = nil,
        bgmFadeDuration: Double? = nil,
        effectiveMedia: Float? = nil,
        effectiveBGM: Float? = nil
    ) {
        let effectiveMedia = effectiveMedia ?? effectiveMediaOutputVolume()
        if let mediaFadeDuration {
            fadeMediaVolume(to: effectiveMedia, duration: mediaFadeDuration)
        } else {
            cleanupBag.mediaVolumeFadeTask?.cancel()
            avCoordinator.volume = effectiveMedia
        }

        let effectiveBGM = effectiveBGM ?? appliedBGMOutputVolume()
        let bgmGeneration = runtime.state.bgm.currentID == nil ? nil : runtime.state.bgm.generation
        if let bgmFadeDuration, let bgmGeneration, bgmAudioPlayer != nil {
            fadeCurrentBGMPlayerVolume(to: effectiveBGM, duration: bgmFadeDuration, generation: bgmGeneration)
        } else {
            cleanupBag.bgmPlayerVolumeFadeTask?.cancel()
            bgmAudioPlayer?.volume = effectiveBGM
        }

        if let bgmFadeDuration, let bgmGeneration {
            fadeCurrentBGMFallbackVolume(to: effectiveBGM, duration: bgmFadeDuration, generation: bgmGeneration)
        } else {
            cleanupBag.bgmFallbackVolumeFadeTask?.cancel()
            bgmFallbackPlayer.volume = effectiveBGM
        }
    }

    private func appliedBGMOutputVolume(sourceState: LiveRuntimeState? = nil) -> Float {
        let state = sourceState ?? runtime.state
        return state.bgm.isPlaying ? state.audio.effectiveBGM : 0
    }

    func applyAudioRoutingForRuntimeChange(
        reason: AudioRoutingRuntimeChangeReason,
        runtimeState: LiveRuntimeState
    ) {
        let transition = AudioRoutingTransitionPolicy.transition(
            for: reason,
            liveAudioFadeDuration: liveAudioFadeDuration
        )
        applyLastAudioRoutingTransitionFromRuntime(transition)
        applyAudioRouting(
            mediaFadeDuration: transition.mediaFadeDuration,
            bgmFadeDuration: transition.bgmFadeDuration,
            effectiveMedia: runtimeState.audio.effectiveMedia,
            effectiveBGM: appliedBGMOutputVolume(sourceState: runtimeState)
        )
    }

    func applyCurrentRuntimeAudioRouting(reason: AudioRoutingRuntimeChangeReason) {
        syncRuntimeAudioInputsFromFacade(reason: reason)
    }

    func fadeMediaVolume(to targetVolume: Float, duration: Double) {
        cleanupBag.mediaVolumeFadeTask?.cancel()
        guard duration > 0 else {
            avCoordinator.volume = targetVolume
            return
        }

        cleanupBag.mediaVolumeFadeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let startVolume = self.avCoordinator.volume
            await self.runLinearFade(
                from: startVolume,
                to: targetVolume,
                duration: duration
            ) { [weak self] volume in
                self?.avCoordinator.volume = volume
            }
        }
    }

    func setupSystemVolumeObserver() {
        guard cleanupBag.systemVolumeObserver == nil else { return }
        let observer = SystemVolumeObserver { [weak self] volume, deviceID in
            guard let self else { return }
            if abs(volume - self.masterVolume) > 0.01 {
                self.masterVolume = volume
                LiveSwitcherTelemetry.systemVolumeSynced(volume: volume, deviceID: deviceID)
                self.recordSupportEvent(
                    kind: .systemVolumeSynced,
                    detail: "deviceID=\(deviceID),volume=\(String(format: "%.3f", volume))"
                )
            }
        }
        cleanupBag.systemVolumeObserver = observer
        observer.start()
    }
}
