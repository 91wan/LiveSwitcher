import AVFoundation
import Foundation

@MainActor
extension SwitcherViewModel {
    func playCurrentRuntimeBGM(generation: Int) {
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

    func pauseCurrentRuntimeBGM(generation: Int) {
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

    func stopCurrentRuntimeBGM(fade: TimeInterval, generation: Int) {
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

    func applyRuntimeBGMVolume(_ volume: Float, fade: TimeInterval, generation: Int) {
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
}
