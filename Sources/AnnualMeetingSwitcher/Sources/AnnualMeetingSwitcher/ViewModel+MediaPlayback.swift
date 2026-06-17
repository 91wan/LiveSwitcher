import Combine
import Foundation
import SwiftUI

extension SwitcherViewModel {
    var currentProgramIsMediaSource: Bool {
        currentProgramItem?.sourceKind == .media
    }

    func setupPlayerCoordinator() {
        let isPlayingCancellable = avCoordinator.$isPlaying
            .receive(on: RunLoop.main)
            .sink { [weak self] isPlaying in
                self?.dispatchRuntimeMediaCallback {
                    .mediaPlaybackChanged(isPlaying: isPlaying, generation: $0)
                }
            }
        storeMediaPlaybackCancellable(isPlayingCancellable)

        avCoordinator.onPlaybackEnded = { [weak self] in
            self?.handlePlaybackEnded()
        }
    }

    /// 将 HTML 文件推送到副屏 WKWebView
    func openHTMLInOutputWindow(url: URL) {
        currentHTMLURL = url
        // Observation tracks currentHTMLURL changes; no manual invalidation is needed.
    }

    /// 结束 HTML 展示，回到空闲壁纸态。
    func endHTMLPresentation() {
        currentHTMLURL = nil
        clearCurrentProgramSelection(reason: .htmlPresentationEnded)
    }

    /// 当前节目播毕后的最小状态回退。
    func handlePlaybackEnded() {
        guard dispatchRuntimeMediaCallback({ .mediaReachedEnd(generation: $0) }) else { return }

        LiveSwitcherTelemetry.playbackReachedEnd()
        recordSupportEvent(kind: .playbackReachedEnd, detail: "state=ended")

        guard !runtimeBackedPanicIsActiveForPlaybackEnded else {
            markPanicSnapshotMediaStoppedIfCurrentProgram(runtimeBackedCurrentProgramForPlaybackEnded?.id)
            return
        }

        if autoPlayNextVideoIfPossible() {
            return
        }

        withAnimation(.easeInOut(duration: 0.5)) {
            currentHTMLURL = nil
            clearCurrentProgramSelection(reason: .mediaPlaybackEnded)
        }
    }

    private func autoPlayNextVideoIfPossible() -> Bool {
        let current = runtimeBackedCurrentProgramForPlaybackEnded
        let queue = runtimeBackedProgramItemsForPlaybackEnded

        guard runtimeBackedAutoPlayNextVideoOnEndForPlaybackEnded,
              let nextItem = ProgramQueueStore.nextVideoAfterCurrent(
                current: current,
                in: queue
              ) else { return false }
        switchToProgram(nextItem)
        return runtimeBackedCurrentProgramForPlaybackEnded?.id == nextItem.id
    }

    private var runtimeBackedPanicIsActiveForPlaybackEnded: Bool {
        runtime.bridgeMode.owns(.panic)
            ? runtime.state.panic.isActive
            : isPanicMode
    }

    private var runtimeBackedCurrentProgramForPlaybackEnded: ProgramItem? {
        runtime.bridgeMode.owns(.programSelection)
            ? runtime.state.program.effectiveCurrentItem
            : currentProgramItem
    }

    private var runtimeBackedProgramItemsForPlaybackEnded: [ProgramItem] {
        runtime.bridgeMode.owns(.programQueue)
            ? runtime.state.program.items
            : programItems
    }

    private var runtimeBackedAutoPlayNextVideoOnEndForPlaybackEnded: Bool {
        runtime.bridgeMode.owns(.persistence)
            ? runtime.state.preferences.autoPlayNextVideoOnEnd
            : autoPlayNextVideoOnEnd
    }
}
