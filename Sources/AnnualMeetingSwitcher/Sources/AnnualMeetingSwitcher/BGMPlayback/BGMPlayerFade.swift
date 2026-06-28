import AVFoundation
import Foundation

@MainActor
extension SwitcherViewModel {
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

    func fadeRetiredBGMPlayerVolume(_ player: AVAudioPlayer, to targetVolume: Float, duration: Double) {
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

    func releaseRetiredBGMPlayerAfterFade(_ player: AVAudioPlayer, duration: Double) {
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

    func releaseBGMFallbackAfterFade(duration: Double, generation: Int) {
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

    func runBGMReturnToStartFade(
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
}
