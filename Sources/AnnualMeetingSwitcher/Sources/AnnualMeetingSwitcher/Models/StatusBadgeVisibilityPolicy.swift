import Foundation

struct StatusBadgeVisibilityPolicy {
    static func shouldShow(text: String, kind: StudioTheme.StatusKind) -> Bool {
        switch kind {
        case .fail, .warn, .live, .muted:
            return true
        case .ready:
            return activeReadyTexts.contains(normalized(text))
        case .idle:
            return false
        }
    }

    private static let activeReadyTexts: Set<String> = ["PLAYING", "播放中"]

    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}
