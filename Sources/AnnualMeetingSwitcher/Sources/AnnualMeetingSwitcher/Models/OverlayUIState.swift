import Foundation

enum OverlayUIState {
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
        return nil
    }

    static func countdownDisabledReason(minutes: Int, seconds: Int, isLive: Bool) -> String? {
        if isLive { return "Countdown is already live." }
        let input = OverlayCountdownInput(minutes: minutes, seconds: seconds)
        return input.disabledReason
    }
}

struct OverlayCountdownInput: Equatable {
    static let maxMinutes = 999
    static let maxSeconds = 59

    let minutes: Int
    let seconds: Int

    var totalSeconds: Int? {
        guard disabledReason == nil else { return nil }
        return minutes * 60 + seconds
    }

    var disabledReason: String? {
        if minutes < 0 || seconds < 0 {
            return "Countdown values cannot be negative."
        }
        if seconds > Self.maxSeconds {
            return "Seconds must be between 0 and 59."
        }
        if minutes > Self.maxMinutes {
            return "Countdown cannot exceed 999:59."
        }
        if minutes == 0 && seconds == 0 {
            return "Set a positive countdown duration before starting."
        }
        return nil
    }
}
