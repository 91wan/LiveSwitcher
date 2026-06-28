import AVFoundation

@MainActor
extension SwitcherViewModel {
    func prepareRuntimeBGMPlayer(_ item: BGMItem, generation: Int) {
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

    func applyRuntimeBGMPlayMode(_ playMode: BGMPlayMode, generation: Int?) {
        if let generation {
            guard runtime.state.bgm.generation == generation else { return }
        }
        bgmAudioPlayer?.numberOfLoops = BGMPlaybackEndPolicy.numberOfLoops(for: playMode)
    }
}
