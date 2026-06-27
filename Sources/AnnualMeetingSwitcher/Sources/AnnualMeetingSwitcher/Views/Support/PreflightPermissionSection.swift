import SwiftUI

enum PreflightPermissionSection {
    static func help(for action: LivePreflightActionKind) -> String {
        switch action {
        case .clearOverlays:
            return "清除倒计时、游动字幕和人名条。"
        case .turnOffPanic:
            return "关闭当前紧急切黑。"
        case .openPreview:
            return "打开导播台页面。"
        case .openAudioMixer:
            return "打开音频页面。"
        case .openOverlays:
            return "打开叠层字幕页面。"
        case .needsHardware:
            return "需要外接显示器硬件，无法自动完成。"
        case .manualReview:
            return "仅提示人工复核，不改变应用状态。"
        }
    }

    static func guidanceIcon(for action: LivePreflightActionKind) -> String {
        switch action {
        case .needsHardware:
            return "display.2"
        case .manualReview:
            return "person.crop.circle.badge.questionmark"
        case .clearOverlays, .turnOffPanic, .openPreview, .openAudioMixer, .openOverlays:
            return "info.circle"
        }
    }
}

struct PreflightPermissionGuidanceBadge: View {
    let label: String
    let action: LivePreflightActionKind

    var body: some View {
        Label(label, systemImage: PreflightPermissionSection.guidanceIcon(for: action))
            .font(StudioTheme.TypeScale.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(StudioTheme.Surface.raised, in: Capsule())
            .help(PreflightPermissionSection.help(for: action))
            .accessibilityLabel(label)
            .accessibilityHint(PreflightPermissionSection.help(for: action))
    }
}
