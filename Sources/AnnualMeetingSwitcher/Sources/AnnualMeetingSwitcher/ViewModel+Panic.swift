import SwiftUI
import AVFoundation

// MARK: - Tier1: Panic Button 状态扩展

extension SwitcherViewModel {

    // MARK: - 业务方法

    /// 切换 Panic 模式（老板键）
    func togglePanicMode() {
        if isPanicMode {
            deactivatePanic()
        } else {
            activatePanic()
        }
        LiveSwitcherTelemetry.panicModeChanged(isOn: isPanicMode)
        recordSupportEvent(kind: .panicModeChanged, detail: "isOn=\(isPanicMode)")
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
