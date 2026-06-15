import SwiftUI
import AVFoundation

// MARK: - Tier1: 紧急切黑 State Extension

extension SwitcherViewModel {

    // MARK: - 业务方法

    /// Toggle emergency blackout mode.
    func togglePanicMode() {
        if runtime.bridgeMode.owns(.panic) {
            let oldValue = runtime.state.panic.isActive
            dispatchRuntimeFacadeAction(.operatorSetPanic(!oldValue))
            let newValue = runtime.state.panic.isActive
            guard newValue != oldValue else { return }
            LiveSwitcherTelemetry.panicModeChanged(isOn: newValue)
            recordSupportEvent(kind: .panicModeChanged, detail: "isOn=\(newValue)")
            return
        }

        if isPanicMode {
            deactivatePanic()
        } else {
            activatePanic()
        }
        LiveSwitcherTelemetry.panicModeChanged(isOn: isPanicMode)
        recordSupportEvent(kind: .panicModeChanged, detail: "isOn=\(isPanicMode)")
    }

    /// Fade-to-black is a visual output state only. It must not change panic or audio routing.
    func toggleFadeToBlack() {
        isFadeToBlackActive.toggle()
        recordSupportEvent(kind: .fadeToBlackChanged, detail: "isActive=\(isFadeToBlackActive)")
    }

    // MARK: - Private

    private func activatePanic() {
        panicAudioTransitionGeneration += 1
        capturePanicPlaybackSnapshot()
        setLegacyPanicMode(true)
        if shouldPauseMediaForActivePanic(panicPlaybackSnapshot) {
            dispatchRuntimeFacadeAction(.operatorPausedMediaForPanic(generation: nil))
        } else {
            dispatchRuntimeFacadeAction(.operatorSetPanic(true))
        }
        applyCurrentRuntimeAudioRouting(reason: .panicChanged)
        pausePlaybackForActivePanic(generation: panicAudioTransitionGeneration)
    }

    private func deactivatePanic() {
        dispatchRuntimeFacadeAction(.operatorSetPanic(false))
        panicAudioTransitionGeneration += 1
        cleanupBag.panicAudioPauseTask?.cancel()
        let snapshot = panicPlaybackSnapshot
        setLegacyPanicPlaybackSnapshot(nil)
        setLegacyPanicMode(false)
        if shouldResumeMediaAfterPanic(snapshot) {
            dispatchRuntimeFacadeAction(.operatorResumedMediaAfterPanic(generation: nil))
        }
        if shouldResumeBGMAfterPanic(snapshot) {
            dispatchRuntimeFacadeAction(.operatorResumedBGMAfterPanic(generation: nil))
        }
        applyCurrentRuntimeAudioRouting(reason: .panicChanged)
    }

    private func capturePanicPlaybackSnapshot() {
        setLegacyPanicPlaybackSnapshot(PanicTransitionPolicy.snapshot(
            currentProgram: currentProgramItem,
            isMediaPlaying: avCoordinator.isPlaying,
            currentBGM: currentBGMItem,
            isBGMPlaying: isBGMPlaying
        ))
    }

    private func shouldResumeMediaAfterPanic(_ snapshot: PanicPlaybackSnapshot?) -> Bool {
        PanicTransitionPolicy.shouldResumeMediaAfterDeactivation(
            snapshot: snapshot,
            currentProgram: currentProgramItem
        )
    }

    private func shouldResumeBGMAfterPanic(_ snapshot: PanicPlaybackSnapshot?) -> Bool {
        PanicTransitionPolicy.shouldResumeBGMAfterDeactivation(
            snapshot: snapshot,
            currentBGM: currentBGMItem
        )
    }

    private func pausePlaybackForActivePanic(generation: Int) {
        let snapshot = panicPlaybackSnapshot
        let delay = max(0, liveAudioFadeDuration)

        cleanupBag.panicAudioPauseTask?.cancel()
        guard delay > 0 else {
            pauseBGMPlaybackAfterPanicFade(snapshot, generation: generation)
            return
        }

        cleanupBag.panicAudioPauseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, self.isPanicMode, self.panicAudioTransitionGeneration == generation else { return }
            self.pauseBGMPlaybackAfterPanicFade(snapshot, generation: generation)
        }
    }

    private func pauseBGMPlaybackAfterPanicFade(_ snapshot: PanicPlaybackSnapshot?, generation: Int) {
        guard isPanicMode, panicAudioTransitionGeneration == generation else { return }
        if shouldPauseBGMForActivePanic(snapshot) {
            dispatchRuntimeFacadeAction(.operatorPausedBGMForPanic(generation: nil))
        }
    }

    private func shouldPauseMediaForActivePanic(_ snapshot: PanicPlaybackSnapshot?) -> Bool {
        PanicTransitionPolicy.shouldPauseMediaForActivation(
            snapshot: snapshot,
            currentProgram: currentProgramItem
        )
    }

    private func shouldPauseBGMForActivePanic(_ snapshot: PanicPlaybackSnapshot?) -> Bool {
        PanicTransitionPolicy.shouldPauseBGMAfterFadeForActivation(
            snapshot: snapshot,
            currentBGM: currentBGMItem
        )
    }
}
