import AVFoundation

@MainActor
extension SwitcherViewModel {
    func seekRuntimeBGMToBeginningWithSmoothing(generation: Int) {
        guard runtime.state.bgm.generation == generation else { return }
        let plan = BGMReturnToStartSmoothingPolicy.plan(
            phase: runtime.state.bgm.phase,
            effectiveBGM: runtime.state.audio.effectiveBGM,
            isMuted: runtime.state.audio.isMasterMuted || runtime.state.audio.isBGMMuted,
            panicActive: runtime.state.panic.isActive
        )
        switch plan {
        case .noOp:
            return
        case .immediate:
            cleanupBag.bgmReturnToStartTask?.cancel()
            cleanupBag.bgmReturnToStartTask = nil
            seekCurrentRuntimeBGMToBeginning(generation: generation)
        case .smoothed(let fadeOut, let fadeIn):
            cleanupBag.bgmReturnToStartTask?.cancel()
            cleanupBag.bgmPlayerVolumeFadeTask?.cancel()
            cleanupBag.bgmFallbackVolumeFadeTask?.cancel()
            cleanupBag.bgmPlayerVolumeFadeTask = nil
            cleanupBag.bgmFallbackVolumeFadeTask = nil
            let audioPlayer = bgmAudioPlayer
            let fallbackPlayer = bgmFallbackPlayer
            let capturedTargetVolume = runtime.state.audio.effectiveBGM
            cleanupBag.bgmReturnToStartTask = Task { @MainActor [weak self, weak audioPlayer, weak fallbackPlayer] in
                guard let self else { return }
                defer {
                    if !Task.isCancelled {
                        self.cleanupBag.bgmReturnToStartTask = nil
                    }
                }
                await self.runBGMReturnToStartFade(
                    audioPlayer: audioPlayer,
                    fallbackPlayer: fallbackPlayer,
                    to: 0,
                    duration: fadeOut,
                    generation: generation
                )
                guard self.canCompleteBGMReturnToStartSmoothing(generation: generation) else { return }
                self.seekCurrentRuntimeBGMToBeginning(generation: generation)
                guard self.canCompleteBGMReturnToStartSmoothing(generation: generation) else { return }
                let targetVolume = min(capturedTargetVolume, self.runtime.state.audio.effectiveBGM)
                guard targetVolume > 0 else { return }
                await self.runBGMReturnToStartFade(
                    audioPlayer: audioPlayer,
                    fallbackPlayer: fallbackPlayer,
                    to: targetVolume,
                    duration: fadeIn,
                    generation: generation
                )
            }
        }
    }

    func seekCurrentRuntimeBGMToBeginning(generation: Int) {
        guard runtime.state.bgm.generation == generation else { return }
        bgmAudioPlayer?.currentTime = 0
        bgmFallbackPlayer.seek(to: .zero)
        bgmProgressStore.update(currentTime: 0, duration: bgmAudioPlayer?.duration ?? fallbackBGMKnownDuration() ?? 0)
    }

    func seekRuntimeBGMProgress(_ progress: Double, generation: Int) {
        guard runtime.state.bgm.generation == generation else { return }
        let clampedProgress = BGMProgressStore.clampedProgress(progress)
        guard let player = bgmAudioPlayer else {
            guard let duration = fallbackBGMKnownDuration(), duration > 0 else {
                return
            }
            let targetTime = duration * clampedProgress
            bgmFallbackPlayer.seek(to: CMTime(seconds: targetTime, preferredTimescale: 600))
            bgmProgressStore.update(currentTime: targetTime, duration: duration)
            return
        }
        let duration = player.duration
        guard duration > 0 else {
            bgmProgressStore.update(currentTime: 0, duration: 0)
            return
        }
        player.currentTime = duration * clampedProgress
        bgmProgressStore.update(currentTime: player.currentTime, duration: duration)
    }

    func fallbackBGMKnownDuration() -> Double? {
        BGMFallbackDurationPolicy.knownDuration(
            storedDuration: bgmDuration,
            itemDuration: bgmFallbackPlayer.currentItem?.duration.seconds
        )
    }

    func cancelBGMReturnToStartSmoothing() {
        cleanupBag.bgmReturnToStartTask?.cancel()
        cleanupBag.bgmReturnToStartTask = nil
    }

    func canCompleteBGMReturnToStartSmoothing(generation: Int) -> Bool {
        guard runtime.state.bgm.generation == generation else { return false }
        let plan = BGMReturnToStartSmoothingPolicy.plan(
            phase: runtime.state.bgm.phase,
            effectiveBGM: runtime.state.audio.effectiveBGM,
            isMuted: runtime.state.audio.isMasterMuted || runtime.state.audio.isBGMMuted,
            panicActive: runtime.state.panic.isActive
        )
        guard case .smoothed = plan else { return false }
        return true
    }

    func startRuntimeBGMTimer(generation: Int) {
        stopActiveBGMTimer()
        setBGMTransitionGenerationForRuntime(generation)
        setActiveBGMTimerGenerationForRuntime(generation)
        cleanupBag.bgmProgressTimer = Timer.scheduledTimer(withTimeInterval: BGMProgressStore.updateInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.activeBGMTimerGenerationForRuntime() == generation else { return }
                self.updateBGMProgress(generation: generation)
            }
        }
    }

    func stopRuntimeBGMTimer(generation: Int) {
        guard let activeGeneration = activeBGMTimerGenerationForRuntime() else { return }
        guard activeGeneration <= generation else { return }
        stopActiveBGMTimer()
    }

    private func stopActiveBGMTimer() {
        cleanupBag.bgmProgressTimer?.invalidate()
        cleanupBag.bgmProgressTimer = nil
        setActiveBGMTimerGenerationForRuntime(nil)
    }

    func updateBGMProgress(generation: Int) {
        guard runtime.state.bgm.generation == generation else { return }
        if let player = bgmAudioPlayer {
            let currentTime = player.currentTime
            let duration = player.duration
            runtime.dispatch(.bgmProgressUpdated(time: currentTime, duration: duration, generation: generation))
            syncBGMFacadeFromRuntime()
            updateBGMRealtimeMeter(from: player)
            finishBGMIfProgressReachedEnd(currentTime: currentTime, duration: duration)
        } else if isBGMPlaying {
            let fallbackTime = bgmFallbackPlayer.currentTime().seconds
            let itemDuration = bgmFallbackPlayer.currentItem?.duration.seconds
            let fallbackDuration = bgmDuration ?? ((itemDuration ?? 0) > 0 && itemDuration?.isFinite == true ? itemDuration : nil)
            if fallbackTime.isFinite, let fallbackDuration, fallbackDuration > 0 {
                runtime.dispatch(.bgmProgressUpdated(time: fallbackTime, duration: fallbackDuration, generation: generation))
                syncBGMFacadeFromRuntime()
                finishBGMIfProgressReachedEnd(currentTime: fallbackTime, duration: fallbackDuration)
            }
            resetBGMRealtimeMeter()
        } else {
            resetBGMRealtimeMeter()
        }
    }

    private func finishBGMIfProgressReachedEnd(currentTime: Double, duration: Double?) {
        guard BGMPlaybackEndPolicy.shouldTreatAsFinished(
            isPlaying: isBGMPlaying,
            playMode: bgmPlayMode,
            currentTime: currentTime,
            duration: duration
        ) else { return }
        bgmAudioPlayer?.delegate = nil
        bgmDidFinish()
    }

    func resetBGMRealtimeMeter() {
        bgmRealtimeLevelDB = nil
        audioMeterStore.resetBGMRealtimeLevel()
    }

    private func updateBGMRealtimeMeter(from player: AVAudioPlayer) {
        guard player.isMeteringEnabled, player.numberOfChannels > 0 else {
            resetBGMRealtimeMeter()
            return
        }

        player.updateMeters()
        let level = player.averagePower(forChannel: 0)
        bgmRealtimeLevelDB = level
        audioMeterStore.updateBGMRealtimeLevel(level)
    }
}
