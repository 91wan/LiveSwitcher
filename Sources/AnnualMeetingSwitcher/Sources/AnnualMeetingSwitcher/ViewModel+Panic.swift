import SwiftUI
import AVFoundation

struct PanicPlaybackSnapshot: Equatable {
    var currentProgramID: UUID?
    var wasMediaPlaying: Bool
    var currentBGMID: UUID?
    var wasBGMPlaying: Bool
}

// MARK: - Tier1: 紧急切黑 State Extension

extension SwitcherViewModel {

    // MARK: - 业务方法

    /// Toggle emergency blackout mode.
    func togglePanicMode() {
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
        capturePanicPlaybackSnapshot()
        isPanicMode = true
        applyAudioRoutingForRuntimeChange(reason: .panicChanged)
        pausePlaybackForActivePanic()
    }

    private func deactivatePanic() {
        let snapshot = panicPlaybackSnapshot
        panicPlaybackSnapshot = nil
        isPanicMode = false
        if shouldResumeMediaAfterPanic(snapshot) {
            avCoordinator.volume = 0
            avCoordinator.play()
        }
        if shouldResumeBGMAfterPanic(snapshot) {
            isBGMPlaying = true
            bgmAudioPlayer?.volume = 0
            bgmAudioPlayer?.play()
            bgmFallbackPlayer.volume = 0
            bgmFallbackPlayer.play()
            startBGMTimer()
        }
        applyAudioRoutingForRuntimeChange(reason: .panicChanged)
    }

    private func capturePanicPlaybackSnapshot() {
        panicPlaybackSnapshot = PanicPlaybackSnapshot(
            currentProgramID: currentProgramItem?.id,
            wasMediaPlaying: currentProgramItem?.sourceKind == .media && avCoordinator.isPlaying,
            currentBGMID: currentBGMItem?.id,
            wasBGMPlaying: isBGMPlaying
        )
    }

    private func shouldResumeMediaAfterPanic(_ snapshot: PanicPlaybackSnapshot?) -> Bool {
        guard let snapshot, snapshot.wasMediaPlaying else { return false }
        guard currentProgramItem?.sourceKind == .media else { return false }
        return currentProgramItem?.id == snapshot.currentProgramID
    }

    private func shouldResumeBGMAfterPanic(_ snapshot: PanicPlaybackSnapshot?) -> Bool {
        guard let snapshot, snapshot.wasBGMPlaying else { return false }
        return currentBGMItem?.id == snapshot.currentBGMID
    }

    private func pausePlaybackForActivePanic() {
        let snapshot = panicPlaybackSnapshot
        let delay = max(0, min(liveAudioFadeDuration, 0.25))

        panicAudioPauseTask?.cancel()
        guard delay > 0 else {
            pausePlaybackAfterPanicFade(snapshot)
            return
        }

        panicAudioPauseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, self.isPanicMode else { return }
            self.pausePlaybackAfterPanicFade(snapshot)
        }
    }

    private func pausePlaybackAfterPanicFade(_ snapshot: PanicPlaybackSnapshot?) {
        guard isPanicMode else { return }
        if snapshot?.wasMediaPlaying == true {
            avCoordinator.pause()
        }
        if snapshot?.wasBGMPlaying == true {
            bgmAudioPlayer?.pause()
            bgmFallbackPlayer.pause()
            isBGMPlaying = false
            stopBGMTimer()
        }
    }
}
