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
    }

    // MARK: - Private

    private func activatePanic() {
        // 保存当前音量（恢复用）
        prePanicMediaVolume = avCoordinator.volume
        prePanicBGMVolume   = bgmAudioPlayer?.volume ?? Float(masterVolume * bgmVolume)
        prePanicBGMFallback = bgmFallbackPlayer.volume

        // 静音（不停止播放）
        avCoordinator.volume        = 0
        bgmAudioPlayer?.volume      = 0
        bgmFallbackPlayer.volume    = 0

        isPanicMode = true
    }

    private func deactivatePanic() {
        isPanicMode = false

        // fade-in 恢复音量：0.3s 线性渐入（10步）
        let targetMedia = prePanicMediaVolume
        let targetBGM   = prePanicBGMVolume
        let targetBGMFallback = prePanicBGMFallback
        let steps       = 10
        let stepTime    = 0.3 / Double(steps)

        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepTime * Double(i)) { [weak self] in
                guard let self else { return }
                self.avCoordinator.volume       = targetMedia * Float(i) / Float(steps)
                self.bgmAudioPlayer?.volume     = targetBGM   * Float(i) / Float(steps)
                self.bgmFallbackPlayer.volume   = targetBGMFallback * Float(i) / Float(steps)
            }
        }
    }
}
