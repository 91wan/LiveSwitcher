import Foundation

@MainActor
extension SwitcherViewModel {
    /// Fix Issue #4: 空格键 - 暂停/继续（也处理 Keynote 播放状态）
    func toggleMainVideoPlayback() {
        guard let item = currentProgramItem else { return }

        switch item.sourceKind {
        case .activeDeck, .keynote, .pptx:
            programActivationSideEffects.stopDeck()
            return
        case .html, .agendaMarker, .unsupported:
            return
        case .media:
            break
        }

        guard !isPanicMode else {
            if runtime.state.media.isPlaying || avCoordinator.isPlaying {
                dispatchRuntimeFacadeAction(.operatorPausedMediaForPanic(generation: nil))
                if panicPlaybackSnapshot?.currentProgramID == item.id {
                    panicPlaybackSnapshot?.wasMediaPlaying = false
                }
            }
            return
        }

        // 普通视频
        dispatchRuntimeFacadeAction(.operatorToggledMediaPlayback)
    }

    func togglePause(for item: ProgramItem) {
        guard currentProgramItem?.id == item.id else {
            switchToProgram(item)
            return
        }
        toggleMainVideoPlayback()
    }

    func seekProgramItemToStart(_ item: ProgramItem) {
        if currentProgramItem?.id == item.id && programItemSupportsSeeking(item) {
            dispatchRuntimeFacadeAction(.operatorSeekedCurrentMediaToStart)
        }
    }

    func restartCurrentMediaFromBeginning() {
        guard let item = currentProgramItem,
              programItemSupportsSeeking(item) else { return }
        dispatchRuntimeFacadeAction(.operatorRestartedCurrentMedia)
        recordSupportEvent(kind: .mediaRestarted, detail: "source=current")
    }

    func seekProgramItemToEnd(_ item: ProgramItem) {
        if currentProgramItem?.id == item.id && programItemSupportsSeeking(item) {
            dispatchRuntimeFacadeAction(.operatorSeekedCurrentMediaToEnd)
        }
    }

    private func programItemSupportsSeeking(_ item: ProgramItem) -> Bool {
        item.sourceKind.supportsSeeking
    }
}
