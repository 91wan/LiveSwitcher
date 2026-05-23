import Foundation

enum OverlayUIState {
    static let maxCountdownMinutes = 999
    static let maxCountdownSeconds = (maxCountdownMinutes * 60) + 59

    static func lowerThirdDisabledReason(name: String, isLive: Bool) -> String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "请输入姓名"
        }
        return nil
    }

    static func tickerDisabledReason(text: String, isLive: Bool) -> String? {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "请输入字幕内容"
        }
        return nil
    }

    static func countdownDisabledReason(totalSeconds: Int, isLive: Bool) -> String? {
        if totalSeconds <= 0 {
            return "请设置有效倒计时"
        }
        if totalSeconds > maxCountdownSeconds {
            return "倒计时不能超过 999:59"
        }
        return nil
    }

    static func countdownDisabledReason(minutes: Int, seconds: Int, isLive: Bool) -> String? {
        if minutes < 0 || seconds < 0 {
            return "倒计时不能为负数"
        }
        if seconds > 59 {
            return "秒数需为 0-59"
        }
        guard let totalSeconds = countdownTotalSeconds(minutes: minutes, seconds: seconds) else {
            return "倒计时不能超过 999:59"
        }
        return countdownDisabledReason(totalSeconds: totalSeconds, isLive: isLive)
    }

    static func countdownTotalSeconds(minutes: Int, seconds: Int) -> Int? {
        guard minutes >= 0, seconds >= 0, seconds <= 59 else { return nil }
        let total = minutes * 60 + seconds
        guard total <= maxCountdownSeconds else { return nil }
        return total
    }
}
