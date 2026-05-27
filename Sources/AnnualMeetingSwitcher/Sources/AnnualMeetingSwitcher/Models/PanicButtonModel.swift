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
        let title = isActive ? "紧急切黑: 开" : "紧急切黑"
        let subtitle = isActive ? "黑屏静音 · 媒体暂停" : "一键应急"
        let hint = isActive
            ? "紧急切黑已开启：副屏黑屏，所有音频静音，并暂停当前媒体和暂停 BGM。再次点击恢复。"
            : "紧急切黑：将副屏切黑、静音所有音频，并暂停当前媒体和暂停 BGM。"

        return PanicButtonModel(
            systemImage: isActive ? "eye.slash.fill" : "bolt.fill",
            title: title,
            subtitle: subtitle,
            visualRole: .danger,
            minWidth: ToolbarLayoutMetrics.panicMinWidth,
            height: ToolbarLayoutMetrics.actionHeight,
            help: hint,
            accessibilityLabel: title,
            accessibilityHint: hint
        )
    }
}
