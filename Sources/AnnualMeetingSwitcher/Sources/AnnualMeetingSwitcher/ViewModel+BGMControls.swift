import AppKit
import AVFoundation

// MARK: - BGM 播放代理（V21：实现自动播放下一首）

final class BGMPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    weak var viewModel: SwitcherViewModel?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard let vm = viewModel else { return }
        Task { @MainActor in
            if flag {
                vm.bgmDidFinish(from: player)
            } else {
                vm.bgmDidFail(from: player)
            }
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        guard let vm = viewModel else { return }
        Task { @MainActor in
            vm.bgmDidFail(from: player)
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
        dispatchRuntimeFacadeAction(.operatorSelectedBGMPlayMode(bgmPlayMode))
    }

    /// V21 Fix #1: 当前曲目播放完毕回调
    func bgmDidFinish(from player: AVAudioPlayer) {
        guard bgmAudioPlayer === player else { return }
        guard isBGMPlaying || isPanicMode else { return }
        bgmDidFinish()
    }

    func bgmDidFinish() {
        dispatchRuntimeBGMCallback { .bgmReachedEnd(generation: $0) }
        removeBGMFallbackEndObserver()
        guard !isPanicMode else {
            invalidateBGMTransitionGeneration()
            if panicPlaybackSnapshot?.currentBGMID == currentBGMItem?.id {
                panicPlaybackSnapshot?.wasBGMPlaying = false
            }
            bgmAudioPlayer?.delegate = nil
            bgmAudioPlayer = nil
            bgmFallbackPlayer.pause()
            bgmFallbackPlayer.replaceCurrentItem(with: nil)
            isBGMPlaying = false
            resetBGMRealtimeMeter()
            bgmProgress = 0
            bgmCurrentTime = 0
            bgmDuration = nil
            recordBGMPlaybackState(isPlaying: false, reason: "finishedDuringPanic")
            applyAudioRoutingForRuntimeChange(reason: .bgmPlaybackChanged)
            stopBGMTimer()
            return
        }

        // 单曲循环（numberOfLoops == -1）不会触发 delegate
        guard let current = currentBGMItem else {
            invalidateBGMTransitionGeneration()
            isBGMPlaying = false
            clearBGMTakeoverIfNeeded()
            resetBGMRealtimeMeter()
            recordBGMPlaybackState(isPlaying: false, reason: "finished")
            applyAudioRoutingForRuntimeChange(reason: .bgmPlaybackChanged)
            stopBGMTimer()
            return
        }

        if bgmPlayMode == .loopOne {
            restartLoopingBGM(current)
            return
        }

        let items = bgmItems.filter { $0.category == current.category }
        guard let index = items.firstIndex(where: { $0.id == current.id }) else {
            invalidateBGMTransitionGeneration()
            isBGMPlaying = false
            clearBGMTakeoverIfNeeded()
            resetBGMRealtimeMeter()
            recordBGMPlaybackState(isPlaying: false, reason: "missingCurrent")
            applyAudioRoutingForRuntimeChange(reason: .bgmPlaybackChanged)
            stopBGMTimer()
            return
        }

        // 顺序播放：到最后一首时停止
        if bgmPlayMode == .sequential && index == items.count - 1 {
            finishSequentialBGMPlayback()
            return
        }

        bgmAudioPlayer?.delegate = nil
        bgmAudioPlayer = nil
        resetBGMRealtimeMeter()

        // 列表循环 / 顺序播放（非最后一首）：播放下一首
        let nextIndex = (index + 1) % items.count
        let nextItem = items[nextIndex]
        if nextItem.id == current.id {
            currentBGMItem = nil
            isBGMPlaying = false
        }
        toggleBGM(nextItem)
    }

    private func finishSequentialBGMPlayback() {
        invalidateBGMTransitionGeneration()
        bgmAudioPlayer?.delegate = nil
        bgmAudioPlayer = nil
        isBGMPlaying = false
        clearBGMTakeoverIfNeeded()
        resetBGMRealtimeMeter()
        recordBGMPlaybackState(isPlaying: false, reason: "finished")
        applyAudioRoutingForRuntimeChange(reason: .bgmPlaybackChanged)
        stopBGMTimer()
        removeBGMFallbackEndObserver()
        bgmFallbackPlayer.seek(to: .zero)
        bgmFallbackPlayer.replaceCurrentItem(with: nil)
    }

    private func restartLoopingBGM(_ item: BGMItem) {
        stopBGMTimer()
        bgmAudioPlayer?.delegate = nil
        bgmAudioPlayer = nil
        resetBGMRealtimeMeter()
        removeBGMFallbackEndObserver()
        bgmFallbackPlayer.pause()
        bgmFallbackPlayer.replaceCurrentItem(with: nil)
        currentBGMItem = nil
        toggleBGM(item)
    }

    func bgmDidFail(from player: AVAudioPlayer) {
        guard bgmAudioPlayer === player else { return }
        bgmDidFail()
    }

    func bgmDidFail() {
        dispatchRuntimeBGMCallback { .bgmFailed(reason: "playbackFailed", generation: $0) }
        invalidateBGMTransitionGeneration()
        if isPanicMode, panicPlaybackSnapshot?.currentBGMID == currentBGMItem?.id {
            panicPlaybackSnapshot?.wasBGMPlaying = false
        }
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

        dispatchRuntimeFacadeAction(.operatorSelectedNextBGM)
        toggleBGM(nextItem)
    }

    func playPreviousBGM() {
        guard let current = currentBGMItem else { return }
        let items = bgmItems.filter { $0.category == current.category }
        guard items.count > 1 else { return }
        guard let index = items.firstIndex(where: { $0.id == current.id }) else { return }

        let prevIndex = (index - 1 + items.count) % items.count
        let prevItem = items[prevIndex]

        dispatchRuntimeFacadeAction(.operatorSelectedPreviousBGM)
        toggleBGM(prevItem)
    }
}
