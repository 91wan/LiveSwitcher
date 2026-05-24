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
        let title = isActive ? "老板键: 开" : "老板键"
        let subtitle = isActive ? "切黑静音" : "紧急切黑"
        let hint = isActive
            ? "老板键已激活：副屏已切黑，音频已静音（再次点击恢复）"
            : "老板键（紧急）：一键切黑副屏并静音所有音频"

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
