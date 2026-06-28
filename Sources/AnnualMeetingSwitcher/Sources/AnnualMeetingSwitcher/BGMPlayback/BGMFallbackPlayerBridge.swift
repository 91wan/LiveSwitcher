import AVFoundation
import Foundation

@MainActor
extension SwitcherViewModel {
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

    func retireCurrentBGMFallbackPlayerForSwitch(duration: Double) {
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
}
