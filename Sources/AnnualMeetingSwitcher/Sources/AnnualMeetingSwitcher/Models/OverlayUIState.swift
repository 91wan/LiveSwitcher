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
}
