import Foundation

enum LiveOverlayPresetInteraction: Equatable {
    case create(OverlayComposerKind)
    case choose
}

struct LiveOverlayRailRowModel: Equatable {
    var title: String
    var presetLabel: String
    var presetInteraction: LiveOverlayPresetInteraction
    var isPlaceholder: Bool
    var isLive: Bool
    var canToggle: Bool
    var disabledHint: String

    var toggleText: String {
        isLive ? "关闭" : "上屏"
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
            presetLabel: selected.map(lowerThirdDisplayName) ?? placeholderLabel(kind: .lowerThird, hasPresets: !presets.isEmpty),
            presetInteraction: interaction(kind: .lowerThird, hasPresets: !presets.isEmpty, hasSelectedPreset: selected != nil),
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
            presetLabel: selected.map { "\($0.title) \(formattedTime($0.totalSeconds))" } ?? placeholderLabel(kind: .countdown, hasPresets: !presets.isEmpty),
            presetInteraction: interaction(kind: .countdown, hasPresets: !presets.isEmpty, hasSelectedPreset: selected != nil),
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
            presetLabel: selected.map { truncated($0.text) } ?? placeholderLabel(kind: .ticker, hasPresets: !presets.isEmpty),
            presetInteraction: interaction(kind: .ticker, hasPresets: !presets.isEmpty, hasSelectedPreset: selected != nil),
            isPlaceholder: selected == nil,
            isLive: isLive,
            canToggle: selected != nil || isLive,
            disabledHint: "请先选择游动字幕预设。"
        )
    }

    private static func placeholderLabel(kind: OverlayComposerKind, hasPresets: Bool) -> String {
        guard !hasPresets else { return "选择预设..." }
        switch kind {
        case .lowerThird:
            return "新建人名条"
        case .countdown:
            return "新建倒计时"
        case .ticker:
            return "新建游动字幕"
        }
    }

    private static func interaction(
        kind: OverlayComposerKind,
        hasPresets: Bool,
        hasSelectedPreset: Bool
    ) -> LiveOverlayPresetInteraction {
        if !hasPresets && !hasSelectedPreset {
            return .create(kind)
        }
        return .choose
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
