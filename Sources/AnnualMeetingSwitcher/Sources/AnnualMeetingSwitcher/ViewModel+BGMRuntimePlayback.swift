import AVFoundation
import Foundation

@MainActor
extension SwitcherViewModel {
    // MARK: - BGM Runtime Playback

    func fadeCurrentBGMFallbackVolume(to targetVolume: Float, duration: Double, generation: Int) {
        cleanupBag.bgmFallbackVolumeFadeTask?.cancel()
        guard duration > 0 else {
            guard runtime.state.bgm.generation == generation else { return }
            bgmFallbackPlayer.volume = targetVolume
            return
        }

        cleanupBag.bgmFallbackVolumeFadeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let startVolume = self.bgmFallbackPlayer.volume
            await self.runLinearFade(
                from: startVolume,
                to: targetVolume,
                duration: duration
            ) { [weak self] volume in
                guard self?.runtime.state.bgm.generation == generation else { return }
                self?.bgmFallbackPlayer.volume = volume
            }
        }
    }

    func fadeCurrentBGMPlayerVolume(to targetVolume: Float, duration: Double, generation: Int) {
        cleanupBag.bgmPlayerVolumeFadeTask?.cancel()
        guard let player = bgmAudioPlayer else { return }
        guard duration > 0 else {
            guard runtime.state.bgm.generation == generation else { return }
            player.volume = targetVolume
            return
        }

        cleanupBag.bgmPlayerVolumeFadeTask = Task { @MainActor [weak self, weak player] in
            guard let self, let player else { return }
            let startVolume = player.volume
            await self.runLinearFade(
                from: startVolume,
                to: targetVolume,
                duration: duration
            ) { [weak player] volume in
                guard self.runtime.state.bgm.generation == generation else { return }
                player?.volume = volume
            }
        }
    }

    func prepareRuntimeBGM(_ item: BGMItem, generation: Int) {
        setActiveRuntimeBGMCallbackIdentity(item: item, generation: generation)
        setBGMTransitionGenerationForRuntime(generation)
        let fadeDuration = liveAudioFadeDuration

        cancelBGMReturnToStartSmoothing()
        cleanupBag.bgmPlayerVolumeFadeTask?.cancel()
        cleanupBag.bgmFallbackVolumeFadeTask?.cancel()
        if let oldPlayer = bgmAudioPlayer {
            fadeRetiredBGMPlayerVolume(oldPlayer, to: 0, duration: fadeDuration)
            releaseRetiredBGMPlayerAfterFade(oldPlayer, duration: fadeDuration)
        }
        bgmAudioPlayer?.delegate = nil
        bgmAudioPlayer = nil
        resetBGMRealtimeMeter()
        removeBGMFallbackEndObserver()
        retireCurrentBGMFallbackPlayerForSwitch(duration: fadeDuration)

        if let player = try? AVAudioPlayer(contentsOf: item.url) {
            player.volume = 0
            player.numberOfLoops = BGMPlaybackEndPolicy.numberOfLoops(for: runtime.state.bgm.playMode)
            player.delegate = bgmDelegate
            player.isMeteringEnabled = true
            player.prepareToPlay()
            bgmAudioPlayer = player
        } else {
            let avItem = AVPlayerItem(url: item.url)
            installBGMFallbackEndObserver(for: avItem)
            bgmFallbackPlayer.replaceCurrentItem(with: avItem)
            bgmFallbackPlayer.volume = 0
            resetBGMRealtimeMeter()
        }
    }

    func playRuntimeBGM(generation: Int) {
        guard runtime.state.bgm.generation == generation else { return }
        if let item = runtime.state.bgm.currentItem {
            setActiveRuntimeBGMCallbackIdentity(item: item, generation: generation)
        }
        setBGMTransitionGenerationForRuntime(generation)
        cancelBGMReturnToStartSmoothing()
        bgmAudioPlayer?.volume = 0
        bgmAudioPlayer?.isMeteringEnabled = true
        bgmAudioPlayer?.play()
        bgmFallbackPlayer.volume = 0
        bgmFallbackPlayer.play()
        let targetVolume = runtime.state.audio.effectiveBGM
        fadeCurrentBGMPlayerVolume(to: targetVolume, duration: liveAudioFadeDuration, generation: generation)
        fadeCurrentBGMFallbackVolume(to: targetVolume, duration: liveAudioFadeDuration, generation: generation)
    }

    func pauseRuntimeBGM(generation: Int) {
        guard runtime.state.bgm.generation == generation else { return }
        setBGMTransitionGenerationForRuntime(generation)
        let fadeDuration = liveAudioFadeDuration
        cancelBGMReturnToStartSmoothing()
        fadeCurrentBGMPlayerVolume(to: 0, duration: fadeDuration, generation: generation)
        fadeCurrentBGMFallbackVolume(to: 0, duration: fadeDuration, generation: generation)
        guard fadeDuration > 0 else {
            bgmAudioPlayer?.pause()
            bgmFallbackPlayer.pause()
            return
        }
        pauseCurrentBGMPlayersAfterFade(duration: fadeDuration, generation: generation, audioPlayer: bgmAudioPlayer)
    }

    func stopRuntimeBGM(fade: TimeInterval, generation: Int) {
        guard runtime.state.bgm.generation == generation else { return }
        clearActiveRuntimeBGMCallbackIdentity()
        setBGMTransitionGenerationForRuntime(generation)
        resetBGMRealtimeMeter()
        clearBGMTakeoverIfNeeded()
        cancelBGMReturnToStartSmoothing()
        cleanupBag.bgmPlayerVolumeFadeTask?.cancel()
        cleanupBag.bgmFallbackVolumeFadeTask?.cancel()
        if let player = bgmAudioPlayer {
            player.delegate = nil
            if fade > 0 {
                fadeRetiredBGMPlayerVolume(player, to: 0, duration: fade)
                releaseRetiredBGMPlayerAfterFade(player, duration: fade)
            } else {
                player.stop()
                player.volume = 0
                player.currentTime = 0
            }
        }
        bgmAudioPlayer = nil
        if fade > 0 {
            fadeCurrentBGMFallbackVolume(to: 0, duration: fade, generation: generation)
            releaseBGMFallbackAfterFade(duration: fade, generation: generation)
        } else {
            removeBGMFallbackEndObserver()
            bgmFallbackPlayer.pause()
            bgmFallbackPlayer.volume = 0
            bgmFallbackPlayer.replaceCurrentItem(with: nil)
        }
    }

    func setRuntimeBGMVolume(_ volume: Float, fade: TimeInterval, generation: Int) {
        guard runtime.state.bgm.generation == generation else { return }
        cancelBGMReturnToStartSmoothing()
        if bgmAudioPlayer != nil {
            fadeCurrentBGMPlayerVolume(to: volume, duration: fade, generation: generation)
        } else {
            cleanupBag.bgmPlayerVolumeFadeTask?.cancel()
            bgmAudioPlayer?.volume = volume
        }
        fadeCurrentBGMFallbackVolume(to: volume, duration: fade, generation: generation)
    }

    func seekRuntimeBGMToBeginning(generation: Int) {
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

    private func seekCurrentRuntimeBGMToBeginning(generation: Int) {
        guard runtime.state.bgm.generation == generation else { return }
        bgmAudioPlayer?.currentTime = 0
        bgmFallbackPlayer.seek(to: .zero)
        bgmProgressStore.update(currentTime: 0, duration: bgmAudioPlayer?.duration ?? fallbackBGMKnownDuration() ?? 0)
    }

    func seekRuntimeBGM(toProgress progress: Double, generation: Int) {
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

    func setRuntimeBGMPlayMode(_ playMode: BGMPlayMode, generation: Int?) {
        if let generation {
            guard runtime.state.bgm.generation == generation else { return }
        }
        bgmAudioPlayer?.numberOfLoops = BGMPlaybackEndPolicy.numberOfLoops(for: playMode)
    }

    private func fadeRetiredBGMPlayerVolume(_ player: AVAudioPlayer, to targetVolume: Float, duration: Double) {
        guard duration > 0 else {
            player.volume = targetVolume
            return
        }

        let taskID = UUID()
        cleanupBag.bgmTransitionTasks[taskID] = Task { @MainActor [weak self, weak player] in
            defer { self?.cleanupBag.bgmTransitionTasks[taskID] = nil }
            guard let self, let player else { return }
            let startVolume = player.volume
            await self.runLinearFade(
                from: startVolume,
                to: targetVolume,
                duration: duration
            ) { [weak player] volume in
                player?.volume = volume
            }
        }
    }

    func installBGMFallbackEndObserver(for item: AVPlayerItem) {
        removeBGMFallbackEndObserver()
        let generation = currentBGMTransitionGenerationForRuntime()
        cleanupBag.bgmFallbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self, weak item] _ in
            Task { @MainActor [weak self, weak item] in
                guard let self,
                      let item,
                      self.currentBGMTransitionGenerationForRuntime() == generation,
                      self.bgmFallbackPlayer.currentItem === item
                else { return }
                self.bgmDidFinish()
            }
        }
        cleanupBag.bgmFallbackFailureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self, weak item] _ in
            Task { @MainActor [weak self, weak item] in
                guard let self,
                      let item,
                      self.currentBGMTransitionGenerationForRuntime() == generation,
                      self.bgmFallbackPlayer.currentItem === item
                else { return }
                self.bgmDidFail()
            }
        }
    }

    func removeBGMFallbackEndObserver() {
        if let observer = cleanupBag.bgmFallbackEndObserver {
            NotificationCenter.default.removeObserver(observer)
            self.cleanupBag.bgmFallbackEndObserver = nil
        }
        if let observer = cleanupBag.bgmFallbackFailureObserver {
            NotificationCenter.default.removeObserver(observer)
            self.cleanupBag.bgmFallbackFailureObserver = nil
        }
    }

    func runLinearFade(
        from startVolume: Float,
        to targetVolume: Float,
        duration: Double,
        apply: @escaping (Float) -> Void
    ) async {
        let steps = AudioFadeStepPolicy.stepCount(duration: duration)
        let stepDuration = UInt64((duration / Double(steps)) * 1_000_000_000)

        for step in 1...steps {
            if Task.isCancelled { return }
            let progress = Float(step) / Float(steps)
            apply(startVolume + (targetVolume - startVolume) * progress)
            try? await Task.sleep(nanoseconds: stepDuration)
        }

        if !Task.isCancelled {
            apply(targetVolume)
        }
    }

    private func fallbackBGMKnownDuration() -> Double? {
        BGMFallbackDurationPolicy.knownDuration(
            storedDuration: bgmDuration,
            itemDuration: bgmFallbackPlayer.currentItem?.duration.seconds
        )
    }

    private func cancelBGMReturnToStartSmoothing() {
        cleanupBag.bgmReturnToStartTask?.cancel()
        cleanupBag.bgmReturnToStartTask = nil
    }

    private func canCompleteBGMReturnToStartSmoothing(generation: Int) -> Bool {
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

    private func runBGMReturnToStartFade(
        audioPlayer: AVAudioPlayer?,
        fallbackPlayer: AVPlayer?,
        to targetVolume: Float,
        duration: TimeInterval,
        generation: Int
    ) async {
        guard duration > 0 else {
            guard runtime.state.bgm.generation == generation else { return }
            audioPlayer?.volume = targetVolume
            fallbackPlayer?.volume = targetVolume
            return
        }

        let playerStartVolume = audioPlayer?.volume ?? targetVolume
        let fallbackStartVolume = fallbackPlayer?.volume ?? targetVolume
        let steps = AudioFadeStepPolicy.stepCount(duration: duration)
        let stepDuration = UInt64((duration / Double(steps)) * 1_000_000_000)

        for step in 1...steps {
            guard !Task.isCancelled, runtime.state.bgm.generation == generation else { return }
            let progress = Float(step) / Float(steps)
            audioPlayer?.volume = playerStartVolume + (targetVolume - playerStartVolume) * progress
            fallbackPlayer?.volume = fallbackStartVolume + (targetVolume - fallbackStartVolume) * progress
            try? await Task.sleep(nanoseconds: stepDuration)
        }

        guard !Task.isCancelled, runtime.state.bgm.generation == generation else { return }
        audioPlayer?.volume = targetVolume
        fallbackPlayer?.volume = targetVolume
    }

    private func rewindBGMIfAtEndBeforeResume() {
        let endTolerance = 0.05
        if let player = bgmAudioPlayer, player.duration > 0 {
            let restartThreshold = max(0, player.duration - endTolerance)
            if player.currentTime >= restartThreshold {
                player.currentTime = 0
                bgmProgressStore.update(currentTime: 0, duration: player.duration)
            }
        }

        guard let duration = fallbackBGMKnownDuration(), duration > 0 else { return }
        let currentTime = bgmFallbackPlayer.currentTime().seconds
        guard currentTime.isFinite else { return }
        let restartThreshold = max(0, duration - endTolerance)
        if currentTime >= restartThreshold {
            bgmFallbackPlayer.seek(to: .zero)
            bgmProgressStore.update(currentTime: 0, duration: duration)
        }
    }

    private func startBGMTimer() {
        startBGMTimer(generation: currentBGMTransitionGenerationForRuntime())
    }

    func startBGMTimer(generation: Int) {
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

    private func stopBGMTimer() {
        stopActiveBGMTimer()
    }

    private func stopActiveBGMTimer() {
        cleanupBag.bgmProgressTimer?.invalidate()
        cleanupBag.bgmProgressTimer = nil
        setActiveBGMTimerGenerationForRuntime(nil)
    }

    func stopBGMTimer(generation: Int) {
        guard let activeGeneration = activeBGMTimerGenerationForRuntime() else { return }
        guard activeGeneration <= generation else { return }
        stopActiveBGMTimer()
    }

    private func releaseRetiredBGMPlayerAfterFade(_ player: AVAudioPlayer, duration: Double) {
        let taskID = UUID()
        cleanupBag.bgmTransitionTasks[taskID] = Task { @MainActor [weak self] in
            defer { self?.cleanupBag.bgmTransitionTasks[taskID] = nil }
            let releaseDelay = BGMFadeCompletionPolicy.pauseDelay(fadeDuration: duration)
            if releaseDelay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(releaseDelay * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            player.delegate = nil
            player.stop()
        }
    }

    private func releaseBGMFallbackAfterFade(duration: Double, generation: Int) {
        let taskID = UUID()
        cleanupBag.bgmTransitionTasks[taskID] = Task { @MainActor [weak self] in
            defer { self?.cleanupBag.bgmTransitionTasks[taskID] = nil }
            let releaseDelay = BGMFadeCompletionPolicy.pauseDelay(fadeDuration: duration)
            if releaseDelay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(releaseDelay * 1_000_000_000))
            }
            guard let self, !Task.isCancelled, self.currentBGMTransitionGenerationForRuntime() == generation else { return }
            guard !self.isBGMPlaying else { return }
            self.bgmFallbackPlayer.volume = 0
            self.bgmFallbackPlayer.pause()
            self.removeBGMFallbackEndObserver()
            self.bgmFallbackPlayer.replaceCurrentItem(with: nil)
        }
    }

    private func pauseCurrentBGMPlayersAfterFade(duration: Double, generation: Int, audioPlayer: AVAudioPlayer?) {
        let taskID = UUID()
        cleanupBag.bgmTransitionTasks[taskID] = Task { @MainActor [weak self, weak audioPlayer] in
            defer { self?.cleanupBag.bgmTransitionTasks[taskID] = nil }
            let pauseDelay = BGMFadeCompletionPolicy.pauseDelay(fadeDuration: duration)
            if pauseDelay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(pauseDelay * 1_000_000_000))
            }
            guard let self, !Task.isCancelled else { return }
            guard self.runtime.state.bgm.generation == generation else { return }
            guard self.runtime.state.bgm.phase == .paused else { return }
            audioPlayer?.pause()
            self.bgmFallbackPlayer.pause()
        }
    }

    private func retireCurrentBGMFallbackPlayerForSwitch(duration: Double) {
        guard bgmFallbackPlayer.currentItem != nil else { return }

        let player = bgmFallbackPlayer
        let taskID = UUID()
        cleanupBag.retiredBGMFallbackPlayers[taskID] = player
        bgmFallbackPlayer = AVPlayer()

        cleanupBag.bgmTransitionTasks[taskID] = Task { @MainActor [weak self, weak player] in
            defer {
                self?.cleanupBag.bgmTransitionTasks[taskID] = nil
                self?.cleanupBag.retiredBGMFallbackPlayers[taskID] = nil
            }
            guard let self, let player else { return }
            if duration > 0 {
                await self.runLinearFade(
                    from: player.volume,
                    to: 0,
                    duration: duration
                ) { [weak player] volume in
                    player?.volume = volume
                }
            } else {
                player.volume = 0
            }
            guard !Task.isCancelled else { return }
            player.volume = 0
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
    }

    func cancelBGMFallbackFade() {
        cleanupBag.bgmFallbackVolumeFadeTask?.cancel()
        cleanupBag.bgmFallbackVolumeFadeTask = nil
    }

    private func updateBGMProgress(generation: Int) {
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
