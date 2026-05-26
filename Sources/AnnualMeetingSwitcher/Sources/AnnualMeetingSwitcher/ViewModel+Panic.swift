import SwiftUI
import AVFoundation

struct PanicPlaybackSnapshot: Equatable {
    var currentProgramID: UUID?
    var wasMediaPlaying: Bool
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
        if panicPlaybackSnapshot?.wasMediaPlaying == true {
            avCoordinator.pause()
        }
        applyAudioRouting(mediaFadeDuration: liveAudioFadeDuration, bgmFadeDuration: liveAudioFadeDuration)
    }

    private func deactivatePanic() {
        let snapshot = panicPlaybackSnapshot
        panicPlaybackSnapshot = nil
        isPanicMode = false
        applyAudioRouting(mediaFadeDuration: liveAudioFadeDuration, bgmFadeDuration: liveAudioFadeDuration)
        if shouldResumeMediaAfterPanic(snapshot) {
            avCoordinator.play()
            applyAudioRouting(mediaFadeDuration: liveAudioFadeDuration)
        }
    }

    private func capturePanicPlaybackSnapshot() {
        guard currentProgramItem?.sourceKind == .media else {
            panicPlaybackSnapshot = nil
            return
        }
        panicPlaybackSnapshot = PanicPlaybackSnapshot(
            currentProgramID: currentProgramItem?.id,
            wasMediaPlaying: avCoordinator.isPlaying
        )
    }

    private func shouldResumeMediaAfterPanic(_ snapshot: PanicPlaybackSnapshot?) -> Bool {
        guard let snapshot, snapshot.wasMediaPlaying else { return false }
        guard currentProgramItem?.sourceKind == .media else { return false }
        return currentProgramItem?.id == snapshot.currentProgramID
    }
}
