import SwiftUI
import AVFoundation

// MARK: - Tier1: Blackout State Extension

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
        isPanicMode = true
        applyAudioRouting(mediaFadeDuration: liveAudioFadeDuration, bgmFadeDuration: liveAudioFadeDuration)
    }

    private func deactivatePanic() {
        isPanicMode = false
        applyAudioRouting(mediaFadeDuration: liveAudioFadeDuration, bgmFadeDuration: liveAudioFadeDuration)
    }
}
