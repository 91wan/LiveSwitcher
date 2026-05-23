import Foundation

enum OverlayUIState {
    static let maxCountdownMinutes = 999
    static let maxCountdownSeconds = (maxCountdownMinutes * 60) + 59

    static func lowerThirdDisabledReason(name: String, isLive: Bool) -> String? {
        if isLive { return "Lower third is already live." }
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter a name before sending the lower third live."
        }
        return nil
    }

    static func tickerDisabledReason(text: String, isLive: Bool) -> String? {
        if isLive { return "Ticker is already live." }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter ticker text before starting."
        }
        return nil
    }

    static func countdownDisabledReason(totalSeconds: Int, isLive: Bool) -> String? {
        if isLive { return "Countdown is already live." }
        if totalSeconds <= 0 {
            return "Set a positive countdown duration before starting."
        }
        if totalSeconds > maxCountdownSeconds {
            return "Countdown cannot exceed 999:59."
        }
        return nil
    }

    static func countdownDisabledReason(minutes: Int, seconds: Int, isLive: Bool) -> String? {
        if isLive { return "Countdown is already live." }
        if minutes < 0 || seconds < 0 {
            return "Countdown values cannot be negative."
        }
        if seconds > 59 {
            return "Seconds must be between 0 and 59."
        }
        guard let totalSeconds = countdownTotalSeconds(minutes: minutes, seconds: seconds) else {
            return "Countdown cannot exceed 999:59."
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
