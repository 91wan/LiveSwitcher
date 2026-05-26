import CoreGraphics
import Foundation

enum PanicButtonVisualRole: Equatable {
    case danger
}

struct PanicButtonModel: Equatable {
    var systemImage: String
    var title: String
    var subtitle: String
    var visualRole: PanicButtonVisualRole
    var minWidth: CGFloat
    var height: CGFloat
    var help: String
    var accessibilityLabel: String
    var accessibilityHint: String

    static func make(isActive: Bool, consoleMode: ConsoleMode) -> PanicButtonModel {
        let liveMode = consoleMode == .live
        let title = isActive ? "紧急切黑: 开" : "紧急切黑"
        let subtitle = isActive ? "副屏黑屏 · 音频静音" : "一键应急"
        let hint = isActive
            ? "紧急切黑已开启：副屏黑屏，所有音频静音。再次点击恢复。"
            : "紧急切黑：将副屏切黑并静音所有音频。"

        return PanicButtonModel(
            systemImage: isActive ? "eye.slash.fill" : "bolt.fill",
            title: title,
            subtitle: subtitle,
            visualRole: .danger,
            minWidth: ToolbarLayoutMetrics.panicMinWidth + (liveMode ? 32 : 0),
            height: liveMode ? 58 : ToolbarLayoutMetrics.actionHeight,
            help: hint,
            accessibilityLabel: title,
            accessibilityHint: hint
        )
    }
}
