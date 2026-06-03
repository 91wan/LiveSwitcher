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
        if isPanicMode, panicPlaybackSnapshot?.currentBGMID == currentBGMItem?.id {
            panicPlaybackSnapshot?.wasBGMPlaying = false
        }
        recordBGMPlaybackState(isPlaying: isBGMPlaying, reason: isBGMPlaying ? "advanced" : "finished")
    }

    func bgmDidFail(from player: AVAudioPlayer) {
        guard bgmAudioPlayer === player else { return }
        bgmDidFail()
    }

    func bgmDidFail() {
        dispatchRuntimeBGMCallback { .bgmFailed(reason: "playbackFailed", generation: $0) }
        if isPanicMode, panicPlaybackSnapshot?.currentBGMID == currentBGMItem?.id {
            panicPlaybackSnapshot?.wasBGMPlaying = false
        }
        clearBGMTakeoverIfNeeded()
        LiveSwitcherTelemetry.bgmTakeoverChanged(isActive: false)
        recordSupportEvent(kind: .bgmPlaybackFailed, detail: "state=stopped")
    }

    func playNextBGM() {
        dispatchRuntimeFacadeAction(.operatorSelectedNextBGM)
    }

    func playPreviousBGM() {
        dispatchRuntimeFacadeAction(.operatorSelectedPreviousBGM)
    }
}
