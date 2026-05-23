import SwiftUI
import Combine

// MARK: - Tier1: Overlay 叠层状态扩展

extension SwitcherViewModel {

    // MARK: - 倒计时方法

    func startCountdown(minutes: Int, seconds: Int, title: String = "活动即将开始") {
        guard let totalSeconds = OverlayUIState.countdownTotalSeconds(minutes: minutes, seconds: seconds),
              OverlayUIState.countdownDisabledReason(minutes: minutes, seconds: seconds, isLive: false) == nil else {
            return
        }
        startCountdown(seconds: totalSeconds, title: title)
    }

    /// 启动倒计时（秒数，标题）
    func startCountdown(seconds: Int, title: String = "活动即将开始") {
        guard OverlayUIState.countdownDisabledReason(totalSeconds: seconds, isLive: false) == nil else {
            return
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        countdownTitle    = trimmedTitle.isEmpty ? "活动即将开始" : trimmedTitle
        countdownSeconds  = seconds
        isCountdownActive = true
        recordSupportEvent(kind: .countdownStarted, detail: "durationSeconds=\(seconds)")

        // 停止已有 Timer
        countdownTimer?.invalidate()

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] t in
            Task { @MainActor in
                guard let self else {
                    t.invalidate()
                    return
                }
                self.countdownTick()
            }
        }
        countdownTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    /// Advances countdown by one second. Kept as a named path so expiry behavior stays testable.
    func countdownTick() {
        guard isCountdownActive else {
            countdownTimer?.invalidate()
            countdownTimer = nil
            countdownSeconds = 0
            return
        }

        guard countdownSeconds > 1 else {
            stopCountdown()
            return
        }

        countdownSeconds -= 1
    }

    /// 停止倒计时
    func stopCountdown() {
        let wasActive = isCountdownActive
        countdownTimer?.invalidate()
        countdownTimer    = nil
        isCountdownActive = false
        countdownSeconds  = 0
        if wasActive {
            recordSupportEvent(kind: .countdownStopped, detail: "state=stopped")
        }
    }

    // MARK: - 游动字幕方法

    /// 启动游动字幕
    func startTicker(text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        tickerText     = trimmedText
        isTickerActive = true
        recordSupportEvent(kind: .tickerStarted, detail: "state=started")
    }

    /// 停止游动字幕
    func stopTicker() {
        let wasActive = isTickerActive
        isTickerActive = false
        if wasActive {
            recordSupportEvent(kind: .tickerStopped, detail: "state=stopped")
        }
    }

    // MARK: - V27: 下三分之一条方法

    /// 显示人名条（弹簧飞入）
    func showLowerThird(name: String, title: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        lowerThirdName    = trimmedName
        lowerThirdTitle   = title.trimmingCharacters(in: .whitespacesAndNewlines)
        isLowerThirdVisible = true
        recordSupportEvent(kind: .lowerThirdShown, detail: "state=shown")
    }

    /// 隐藏人名条（退场动画后消失）
    func dismissLowerThird() {
        let wasVisible = isLowerThirdVisible
        isLowerThirdVisible = false
        if wasVisible {
            recordSupportEvent(kind: .lowerThirdHidden, detail: "state=hidden")
        }
    }

    /// 一键清空所有大屏叠层
    func clearAllOverlays() {
        stopCountdown()
        stopTicker()
        dismissLowerThird()
        lowerThirdName = ""
        lowerThirdTitle = ""
        recordSupportEvent(kind: .overlaysCleared, detail: "state=cleared")
    }
}
