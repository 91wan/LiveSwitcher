import Foundation

@MainActor
extension SwitcherViewModel {
    /// Fix Issue #4: 空格键 - 暂停/继续（也处理 Keynote 播放状态）
    func toggleMainVideoPlayback() {
        guard let item = runtimeBackedCurrentProgramForMediaTransport else { return }

        switch item.sourceKind {
        case .activeDeck, .keynote, .pptx:
            programActivationSideEffects.stopDeck()
            return
        case .html, .agendaMarker, .unsupported:
            return
        case .media:
            break
        }

        guard !runtimeBackedPanicIsActiveForMediaTransport else {
            if runtimeBackedMediaIsPlayingForMediaTransport {
                dispatchRuntimeFacadeAction(.operatorPausedMediaForPanic(generation: nil))
                markPanicSnapshotMediaStoppedIfCurrentProgram(item.id)
            }
            return
        }

        // 普通视频
        dispatchRuntimeFacadeAction(.operatorToggledMediaPlayback)
    }

    func togglePause(for item: ProgramItem) {
        guard runtimeBackedCurrentProgramForMediaTransport?.id == item.id else {
            switchToProgram(item)
            return
        }
        toggleMainVideoPlayback()
    }

    func seekProgramItemToStart(_ item: ProgramItem) {
        if runtimeBackedCurrentProgramForMediaTransport?.id == item.id && programItemSupportsSeeking(item) {
            dispatchRuntimeFacadeAction(.operatorSeekedCurrentMediaToStart)
        }
    }

    func restartCurrentMediaFromBeginning() {
        guard let item = runtimeBackedCurrentProgramForMediaTransport,
              programItemSupportsSeeking(item) else { return }
        dispatchRuntimeFacadeAction(.operatorRestartedCurrentMedia)
        recordSupportEvent(kind: .mediaRestarted, detail: "source=current")
    }

    func seekProgramItemToEnd(_ item: ProgramItem) {
        if runtimeBackedCurrentProgramForMediaTransport?.id == item.id && programItemSupportsSeeking(item) {
            dispatchRuntimeFacadeAction(.operatorSeekedCurrentMediaToEnd)
        }
    }

    private var runtimeBackedCurrentProgramForMediaTransport: ProgramItem? {
        runtime.bridgeMode.owns(.programSelection)
            ? runtime.state.program.effectiveCurrentItem
            : currentProgramItem
    }

    private var runtimeBackedPanicIsActiveForMediaTransport: Bool {
        runtime.bridgeMode.owns(.panic)
            ? runtime.state.panic.isActive
            : isPanicMode
    }

    private var runtimeBackedMediaIsPlayingForMediaTransport: Bool {
        runtime.bridgeMode.owns(.media)
            ? runtime.state.media.isPlaying
            : (runtime.state.media.isPlaying || avCoordinator.isPlaying)
    }

    private func programItemSupportsSeeking(_ item: ProgramItem) -> Bool {
        item.sourceKind.supportsSeeking
    }
}
