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
    // MARK: - BGM Library

    @discardableResult
    func addBGMItem(_ item: BGMItem) -> Bool {
        addBGMItems([item]) == 1
    }

    @discardableResult
    func addBGMItems(_ items: [BGMItem]) -> Int {
        guard !items.isEmpty else { return 0 }
        var importedCount = 0
        for item in items {
            guard BGMDuplicatePolicy.decision(for: item.url, existingItems: bgmItems) != .duplicateURL else {
                recordSupportEvent(kind: .bgmImportSkippedDuplicate, detail: "reason=duplicateURL")
                continue
            }
            bgmItems.append(item)
            importedCount += 1
        }
        if importedCount > 0 {
            saveData()
        }
        return importedCount
    }

    func removeBGMItem(_ item: BGMItem) {
        bgmItems.removeAll { $0.id == item.id }
        if currentBGMItem?.id == item.id {
            dispatchRuntimeFacadeAction(.operatorStoppedBGM)
            recordBGMPlaybackState(isPlaying: false, reason: "removed")
        }
        saveData()
    }

    func moveBGMItems(from source: IndexSet, to destination: Int) {
        bgmItems.move(fromOffsets: source, toOffset: destination)
        saveData()
    }

    func moveBGMItems(in category: BGMCategory, from source: IndexSet, to destination: Int) {
        let categoryOffsets = bgmItems.indices.filter { bgmItems[$0].category == category }
        guard !categoryOffsets.isEmpty else { return }

        var scopedItems = categoryOffsets.map { bgmItems[$0] }
        scopedItems.move(fromOffsets: source, toOffset: destination)

        for (scopedIndex, originalIndex) in categoryOffsets.enumerated() {
            bgmItems[originalIndex] = scopedItems[scopedIndex]
        }
        saveData()
    }

    func seekBGMToBeginning() {
        dispatchRuntimeFacadeAction(.operatorSeekedBGMToBeginning)
    }

    func seekBGM(toProgress progress: Double) {
        dispatchRuntimeFacadeAction(.operatorSeekedBGMToProgress(progress))
    }

    // MARK: - BGM Operator Controls

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
        let nextMode: BGMPlayMode
        switch bgmPlayMode {
        case .loopAll:
            nextMode = .loopOne
        case .loopOne:
            nextMode = .sequential
        case .sequential:
            nextMode = .loopAll
        }
        bgmPlayMode = nextMode
        dispatchRuntimeFacadeAction(.operatorSelectedBGMPlayMode(bgmPlayMode))
    }

    /// V21 Fix #1: 当前曲目播放完毕回调
    func bgmDidFinish(from player: AVAudioPlayer) {
        guard bgmAudioPlayer === player else { return }
        guard isBGMPlaying || isPanicMode else { return }
        bgmDidFinish()
    }

    func bgmDidFinish() {
        guard dispatchRuntimeBGMCallback({ .bgmReachedEnd(generation: $0) }) else { return }
        removeBGMFallbackEndObserver()
        if isPanicMode {
            markPanicSnapshotBGMStoppedIfCurrentBGM(currentBGMItem?.id)
        }
        recordBGMPlaybackState(isPlaying: isBGMPlaying, reason: isBGMPlaying ? "advanced" : "finished")
    }

    func bgmDidFail(from player: AVAudioPlayer) {
        guard bgmAudioPlayer === player else { return }
        bgmDidFail()
    }

    func bgmDidFail() {
        guard dispatchRuntimeBGMCallback({ .bgmFailed(reason: "playbackFailed", generation: $0) }) else { return }
        if isPanicMode {
            markPanicSnapshotBGMStoppedIfCurrentBGM(currentBGMItem?.id)
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

    func toggleBGM(_ item: BGMItem) {
        guard !isPanicMode else {
            cueBGMDuringPanic(item)
            return
        }

        if currentBGMItem?.id == item.id, isBGMPlaying {
            dispatchRuntimeFacadeAction(.operatorStoppedBGM)
            recordBGMPlaybackState(isPlaying: false, reason: "operator")
        } else {
            dispatchRuntimeBGMItemAction(.operatorSelectedBGM(item.id), item: item)
            recordBGMPlaybackState(isPlaying: true, reason: "selected")
        }
    }

    private func cueBGMDuringPanic(_ item: BGMItem) {
        dispatchRuntimeBGMItemAction(.operatorSelectedBGM(item.id), item: item)
        markPanicSnapshotBGMStoppedIfCurrentBGM(item.id)
        recordBGMPlaybackState(isPlaying: false, reason: "cuedDuringPanic")
    }

    private func dispatchRuntimeBGMItemAction(_ action: LiveRuntimeAction, item: BGMItem) {
        includeTransientRuntimeBGMItem(item)
        defer { clearTransientRuntimeBGMItemIfNeeded(item) }
        dispatchRuntimeFacadeAction(action)
    }

    func clearBGMTakeoverIfNeeded() {
        guard isBGMAudioTakeoverActive else { return }
        isBGMAudioTakeoverActive = false
        LiveSwitcherTelemetry.bgmTakeoverChanged(isActive: false)
        recordSupportEvent(kind: .bgmTakeoverChanged, detail: "isActive=false")
    }

    func recordBGMPlaybackState(isPlaying: Bool, reason: String) {
        recordSupportEvent(kind: .bgmPlaybackChanged, detail: "isPlaying=\(isPlaying),reason=\(reason)")
    }
}
