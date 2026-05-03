import SwiftUI
import Combine

// MARK: - Tier1: Overlay 叠层状态扩展

extension SwitcherViewModel {

    // MARK: - 倒计时方法

    /// 启动倒计时（秒数，标题）
    func startCountdown(seconds: Int, title: String = "活动即将开始") {
        guard seconds > 0 else { return }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        countdownTitle    = trimmedTitle.isEmpty ? "活动即将开始" : trimmedTitle
        countdownSeconds  = seconds
        isCountdownActive = true

        // 停止已有 Timer
        countdownTimer?.invalidate()

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            Task { @MainActor in
                if self.countdownSeconds > 0 {
                    self.countdownSeconds -= 1
                } else {
                    self.stopCountdown()
                }
            }
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }

    /// 停止倒计时
    func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer    = nil
        isCountdownActive = false
        countdownSeconds  = 0
    }

    // MARK: - 游动字幕方法

    /// 启动游动字幕
    func startTicker(text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        tickerText     = trimmedText
        isTickerActive = true
    }

    /// 停止游动字幕
    func stopTicker() {
        isTickerActive = false
    }

    // MARK: - V27: 下三分之一条方法

    /// 显示人名条（弹簧飞入）
    func showLowerThird(name: String, title: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        lowerThirdName    = trimmedName
        lowerThirdTitle   = title.trimmingCharacters(in: .whitespacesAndNewlines)
        isLowerThirdVisible = true
    }

    /// 隐藏人名条（退场动画后消失）
    func dismissLowerThird() {
        isLowerThirdVisible = false
    }

    /// 一键清空所有大屏叠层
    func clearAllOverlays() {
        stopCountdown()
        stopTicker()
        dismissLowerThird()
        lowerThirdName = ""
        lowerThirdTitle = ""
    }
}
