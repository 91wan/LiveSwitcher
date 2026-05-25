import Foundation

struct LiveOverlayRailRowModel: Equatable {
    var title: String
    var presetLabel: String
    var isPlaceholder: Bool
    var isLive: Bool
    var canToggle: Bool
    var disabledHint: String

    var toggleText: String {
        isLive ? "LIVE" : "OFF"
    }

    var accessibilityLabel: String {
        "\(title), \(presetLabel), \(toggleText)"
    }

    static func lowerThird(
        presets: [LowerThirdPreset],
        selectedID: UUID?,
        isLive: Bool
    ) -> LiveOverlayRailRowModel {
        let selected = presets.first { $0.id == selectedID }
        return LiveOverlayRailRowModel(
            title: "Lower Third",
            presetLabel: selected?.name ?? placeholderLabel(hasPresets: !presets.isEmpty),
            isPlaceholder: selected == nil,
            isLive: isLive,
            canToggle: selected != nil || isLive,
            disabledHint: "Choose a lower third preset first."
        )
    }

    static func countdown(
        presets: [CountdownPreset],
        selectedID: UUID?,
        isLive: Bool
    ) -> LiveOverlayRailRowModel {
        let selected = presets.first { $0.id == selectedID }
        return LiveOverlayRailRowModel(
            title: "Countdown",
            presetLabel: selected.map { "\($0.title) \(formattedTime($0.totalSeconds))" } ?? placeholderLabel(hasPresets: !presets.isEmpty),
            isPlaceholder: selected == nil,
            isLive: isLive,
            canToggle: selected != nil || isLive,
            disabledHint: "Choose a countdown preset first."
        )
    }

    static func ticker(
        presets: [TickerPreset],
        selectedID: UUID?,
        isLive: Bool
    ) -> LiveOverlayRailRowModel {
        let selected = presets.first { $0.id == selectedID }
        return LiveOverlayRailRowModel(
            title: "Ticker",
            presetLabel: selected.map { truncated($0.text) } ?? placeholderLabel(hasPresets: !presets.isEmpty),
            isPlaceholder: selected == nil,
            isLive: isLive,
            canToggle: selected != nil || isLive,
            disabledHint: "Choose a ticker preset first."
        )
    }

    private static func placeholderLabel(hasPresets: Bool) -> String {
        hasPresets ? "Choose preset..." : "+ New preset"
    }

    private static func formattedTime(_ seconds: Int) -> String {
        let safeSeconds = max(seconds, 0)
        return String(format: "%02d:%02d", safeSeconds / 60, safeSeconds % 60)
    }

    private static func truncated(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let maxCharacters = 21
        guard trimmed.count > maxCharacters else { return trimmed }
        return "\(trimmed.prefix(maxCharacters))..."
    }
}
