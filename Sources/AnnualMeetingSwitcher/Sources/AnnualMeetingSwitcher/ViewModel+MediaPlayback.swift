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
        currentProgramItem = nil
    }

    /// 当前节目播毕后的最小状态回退。
    func handlePlaybackEnded() {
        dispatchRuntimeMediaCallback { .mediaReachedEnd(generation: $0) }
        LiveSwitcherTelemetry.playbackReachedEnd()
        recordSupportEvent(kind: .playbackReachedEnd, detail: "state=ended")

        guard !isPanicMode else {
            if panicPlaybackSnapshot?.currentProgramID == currentProgramItem?.id {
                panicPlaybackSnapshot?.wasMediaPlaying = false
            }
            return
        }

        if autoPlayNextVideoIfPossible() {
            return
        }

        withAnimation(.easeInOut(duration: 0.5)) {
            currentHTMLURL = nil
            currentProgramItem = nil
        }
    }

    private func autoPlayNextVideoIfPossible() -> Bool {
        guard autoPlayNextVideoOnEnd,
              let nextItem = ProgramQueueStore.nextVideoAfterCurrent(
                current: currentProgramItem,
                in: programItems
              ) else { return false }
        switchToProgram(nextItem)
        return currentProgramItem?.id == nextItem.id
    }
}
