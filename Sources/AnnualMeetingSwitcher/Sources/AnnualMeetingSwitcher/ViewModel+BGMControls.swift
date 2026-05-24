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
        applyAudioRouting(mediaFadeDuration: liveAudioFadeDuration, bgmFadeDuration: liveAudioFadeDuration)
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
        // 单曲循环（numberOfLoops == -1）不会触发 delegate
        guard let current = currentBGMItem else {
            isBGMPlaying = false
            isBGMAudioTakeoverActive = false
            resetBGMRealtimeMeter()
            LiveSwitcherTelemetry.bgmTakeoverChanged(isActive: false)
            recordSupportEvent(kind: .bgmTakeoverChanged, detail: "isActive=false")
            applyAudioRouting(mediaFadeDuration: liveAudioFadeDuration)
            stopBGMTimer()
            return
        }

        let items = bgmItems.filter { $0.category == current.category }
        guard let index = items.firstIndex(where: { $0.id == current.id }) else {
            isBGMPlaying = false
            isBGMAudioTakeoverActive = false
            resetBGMRealtimeMeter()
            LiveSwitcherTelemetry.bgmTakeoverChanged(isActive: false)
            recordSupportEvent(kind: .bgmTakeoverChanged, detail: "isActive=false")
            applyAudioRouting(mediaFadeDuration: liveAudioFadeDuration)
            stopBGMTimer()
            return
        }

        bgmAudioPlayer?.delegate = nil
        bgmAudioPlayer = nil
        resetBGMRealtimeMeter()

        // 顺序播放：到最后一首时停止
        if bgmPlayMode == .sequential && index == items.count - 1 {
            isBGMPlaying = false
            isBGMAudioTakeoverActive = false
            resetBGMRealtimeMeter()
            LiveSwitcherTelemetry.bgmTakeoverChanged(isActive: false)
            recordSupportEvent(kind: .bgmTakeoverChanged, detail: "isActive=false")
            applyAudioRouting(mediaFadeDuration: liveAudioFadeDuration)
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
        bgmFallbackPlayer.volume = 0
        bgmFallbackPlayer.pause()
        bgmFallbackPlayer.replaceCurrentItem(with: nil)
        isBGMPlaying = false
        isBGMAudioTakeoverActive = false
        bgmProgress = 0
        bgmCurrentTime = 0
        bgmDuration = nil
        LiveSwitcherTelemetry.bgmTakeoverChanged(isActive: false)
        recordSupportEvent(kind: .bgmPlaybackFailed, detail: "state=stopped")
        applyAudioRouting(mediaFadeDuration: liveAudioFadeDuration, bgmFadeDuration: liveAudioFadeDuration)
    }

    func playNextBGM() {
        guard let current = currentBGMItem else { return }
        let items = bgmItems.filter { $0.category == current.category }
        guard let index = items.firstIndex(where: { $0.id == current.id }) else { return }

        let nextIndex = (index + 1) % items.count
        let nextItem = items[nextIndex]

        bgmAudioPlayer?.stop()
        bgmAudioPlayer?.delegate = nil
        bgmAudioPlayer = nil
        resetBGMRealtimeMeter()
        toggleBGM(nextItem)
    }

    func playPreviousBGM() {
        guard let current = currentBGMItem else { return }
        let items = bgmItems.filter { $0.category == current.category }
        guard let index = items.firstIndex(where: { $0.id == current.id }) else { return }

        let prevIndex = (index - 1 + items.count) % items.count
        let prevItem = items[prevIndex]

        bgmAudioPlayer?.stop()
        bgmAudioPlayer?.delegate = nil
        bgmAudioPlayer = nil
        resetBGMRealtimeMeter()
        toggleBGM(prevItem)
    }
}
