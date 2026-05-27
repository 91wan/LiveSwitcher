import Foundation

struct LiveOverlayRailRowModel: Equatable {
    var title: String
    var presetLabel: String
    var isPlaceholder: Bool
    var isLive: Bool
    var canToggle: Bool
    var disabledHint: String

    var toggleText: String {
        isLive ? "上屏" : "关闭"
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
            title: "人名条",
            presetLabel: selected.map(lowerThirdDisplayName) ?? placeholderLabel(hasPresets: !presets.isEmpty),
            isPlaceholder: selected == nil,
            isLive: isLive,
            canToggle: selected != nil || isLive,
            disabledHint: "请先选择人名条预设。"
        )
    }

    static func countdown(
        presets: [CountdownPreset],
        selectedID: UUID?,
        isLive: Bool
    ) -> LiveOverlayRailRowModel {
        let selected = presets.first { $0.id == selectedID }
        return LiveOverlayRailRowModel(
            title: "倒计时",
            presetLabel: selected.map { "\($0.title) \(formattedTime($0.totalSeconds))" } ?? placeholderLabel(hasPresets: !presets.isEmpty),
            isPlaceholder: selected == nil,
            isLive: isLive,
            canToggle: selected != nil || isLive,
            disabledHint: "请先选择倒计时预设。"
        )
    }

    static func ticker(
        presets: [TickerPreset],
        selectedID: UUID?,
        isLive: Bool
    ) -> LiveOverlayRailRowModel {
        let selected = presets.first { $0.id == selectedID }
        return LiveOverlayRailRowModel(
            title: "游动字幕",
            presetLabel: selected.map { truncated($0.text) } ?? placeholderLabel(hasPresets: !presets.isEmpty),
            isPlaceholder: selected == nil,
            isLive: isLive,
            canToggle: selected != nil || isLive,
            disabledHint: "请先选择游动字幕预设。"
        )
    }

    private static func placeholderLabel(hasPresets: Bool) -> String {
        hasPresets ? "选择预设..." : "+ 新建预设"
    }

    private static func lowerThirdDisplayName(_ preset: LowerThirdPreset) -> String {
        let subtitle = preset.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subtitle.isEmpty else { return preset.name }
        return "\(preset.name) · \(subtitle)"
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
