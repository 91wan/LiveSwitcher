import AppKit
import AVFoundation

// MARK: - BGM 播放代理（V21：实现自动播放下一首）

final class BGMPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    weak var viewModel: SwitcherViewModel?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard let vm = viewModel else { return }
        Task { @MainActor in
            if flag {
                vm.bgmDidFinish()
            } else {
                vm.bgmDidFail()
            }
        }
    }
}

extension SwitcherViewModel {

    func bgmVolumeDown() {
        bgmVolume = max(0, bgmVolume - 0.05)
    }

    func bgmVolumeUp() {
        bgmVolume = min(1.0, bgmVolume + 0.05)
    }

    // MARK: - V26.3: 主讲人模式（一键压限 BGM）

    /// 切换主讲人模式：开启时将 BGM 压低至 7%，关闭时恢复到用户设定音量
    func toggleSpeakerMode() {
        isSpeakerMode.toggle()
        LiveSwitcherTelemetry.speakerModeChanged(isOn: isSpeakerMode)
        recordSupportEvent(kind: .speakerModeChanged, detail: "isOn=\(isSpeakerMode)")
        applyAudioRoutingForRuntimeChange(reason: .speakerChanged)
    }

    // Toggle loop mode: loopAll → loopOne → sequential → loopAll
    func toggleLoopMode() {
        switch bgmPlayMode {
        case .loopAll:
            bgmPlayMode = .loopOne
            bgmAudioPlayer?.numberOfLoops = -1
        case .loopOne:
            bgmPlayMode = .sequential
            bgmAudioPlayer?.numberOfLoops = 0
        case .sequential:
            bgmPlayMode = .loopAll
            bgmAudioPlayer?.numberOfLoops = 0
        }
    }

    /// V21 Fix #1: 当前曲目播放完毕回调
    func bgmDidFinish() {
        removeBGMFallbackEndObserver()
        guard !isPanicMode else {
            isBGMPlaying = false
            resetBGMRealtimeMeter()
            recordBGMPlaybackState(isPlaying: false, reason: "finishedDuringPanic")
            applyAudioRoutingForRuntimeChange(reason: .bgmPlaybackChanged)
            stopBGMTimer()
            return
        }

        // 单曲循环（numberOfLoops == -1）不会触发 delegate
        guard let current = currentBGMItem else {
            isBGMPlaying = false
            clearBGMTakeoverIfNeeded()
            resetBGMRealtimeMeter()
            recordBGMPlaybackState(isPlaying: false, reason: "finished")
            applyAudioRoutingForRuntimeChange(reason: .bgmPlaybackChanged)
            stopBGMTimer()
            return
        }

        let items = bgmItems.filter { $0.category == current.category }
        guard let index = items.firstIndex(where: { $0.id == current.id }) else {
            isBGMPlaying = false
            clearBGMTakeoverIfNeeded()
            resetBGMRealtimeMeter()
            recordBGMPlaybackState(isPlaying: false, reason: "missingCurrent")
            applyAudioRoutingForRuntimeChange(reason: .bgmPlaybackChanged)
            stopBGMTimer()
            return
        }

        bgmAudioPlayer?.delegate = nil
        bgmAudioPlayer = nil
        resetBGMRealtimeMeter()

        // 顺序播放：到最后一首时停止
        if bgmPlayMode == .sequential && index == items.count - 1 {
            isBGMPlaying = false
            clearBGMTakeoverIfNeeded()
            resetBGMRealtimeMeter()
            recordBGMPlaybackState(isPlaying: false, reason: "finished")
            applyAudioRoutingForRuntimeChange(reason: .bgmPlaybackChanged)
            stopBGMTimer()
            return
        }

        // 列表循环 / 顺序播放（非最后一首）：播放下一首
        let nextIndex = (index + 1) % items.count
        toggleBGM(items[nextIndex])
    }

    func bgmDidFail() {
        stopBGMTimer()
        bgmAudioPlayer?.delegate = nil
        bgmAudioPlayer = nil
        resetBGMRealtimeMeter()
        cancelBGMFallbackFade()
        removeBGMFallbackEndObserver()
        bgmFallbackPlayer.volume = 0
        bgmFallbackPlayer.pause()
        bgmFallbackPlayer.replaceCurrentItem(with: nil)
        isBGMPlaying = false
        clearBGMTakeoverIfNeeded()
        bgmProgress = 0
        bgmCurrentTime = 0
        bgmDuration = nil
        LiveSwitcherTelemetry.bgmTakeoverChanged(isActive: false)
        recordSupportEvent(kind: .bgmPlaybackFailed, detail: "state=stopped")
        applyAudioRoutingForRuntimeChange(reason: .bgmPlaybackChanged)
    }

    func playNextBGM() {
        guard let current = currentBGMItem else { return }
        let items = bgmItems.filter { $0.category == current.category }
        guard items.count > 1 else { return }
        guard let index = items.firstIndex(where: { $0.id == current.id }) else { return }

        let nextIndex = (index + 1) % items.count
        let nextItem = items[nextIndex]

        toggleBGM(nextItem)
    }

    func playPreviousBGM() {
        guard let current = currentBGMItem else { return }
        let items = bgmItems.filter { $0.category == current.category }
        guard items.count > 1 else { return }
        guard let index = items.firstIndex(where: { $0.id == current.id }) else { return }

        let prevIndex = (index - 1 + items.count) % items.count
        let prevItem = items[prevIndex]

        toggleBGM(prevItem)
    }
}
