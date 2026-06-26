import Foundation
import AVFoundation

final class ViewModelCleanupBag {
    var mediaVolumeFadeTask: Task<Void, Never>?
    var bgmPlayerVolumeFadeTask: Task<Void, Never>?
    var bgmFallbackVolumeFadeTask: Task<Void, Never>?
    var bgmReturnToStartTask: Task<Void, Never>?
    var bgmProgressTimer: Timer?
    var bgmFallbackEndObserver: NSObjectProtocol?
    var bgmFallbackFailureObserver: NSObjectProtocol?
    var bgmTransitionTasks: [UUID: Task<Void, Never>] = [:]
    var retiredBGMFallbackPlayers: [UUID: AVPlayer] = [:]
    var automationNoticeExpiryTask: Task<Void, Never>?
    var automationNoticeExpiryTaskNoticeID: UUID?
    var panicAudioPauseTask: Task<Void, Never>?
    var panicAudioPauseTaskGeneration: Int?
    var backgroundImageLoadTask: Task<Void, Never>?
    var cornerLogoImageLoadTask: Task<Void, Never>?
    var systemVolumeObserver: SystemVolumeObserver?
    var externalDisplayChangeObserver: NSObjectProtocol?

    func cancelAll() {
        mediaVolumeFadeTask?.cancel()
        bgmPlayerVolumeFadeTask?.cancel()
        bgmFallbackVolumeFadeTask?.cancel()
        bgmReturnToStartTask?.cancel()
        bgmReturnToStartTask = nil
        bgmProgressTimer?.invalidate()
        bgmProgressTimer = nil
        bgmTransitionTasks.values.forEach { $0.cancel() }
        retiredBGMFallbackPlayers.values.forEach { player in
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        retiredBGMFallbackPlayers.removeAll()
        automationNoticeExpiryTask?.cancel()
        automationNoticeExpiryTask = nil
        automationNoticeExpiryTaskNoticeID = nil
        panicAudioPauseTask?.cancel()
        panicAudioPauseTask = nil
        panicAudioPauseTaskGeneration = nil
        backgroundImageLoadTask?.cancel()
        cornerLogoImageLoadTask?.cancel()
        systemVolumeObserver?.stop()
        if let externalDisplayChangeObserver {
            NotificationCenter.default.removeObserver(externalDisplayChangeObserver)
            self.externalDisplayChangeObserver = nil
        }
        if let bgmFallbackEndObserver {
            NotificationCenter.default.removeObserver(bgmFallbackEndObserver)
            self.bgmFallbackEndObserver = nil
        }
        if let bgmFallbackFailureObserver {
            NotificationCenter.default.removeObserver(bgmFallbackFailureObserver)
            self.bgmFallbackFailureObserver = nil
        }
    }

    deinit {
        cancelAll()
    }
}
