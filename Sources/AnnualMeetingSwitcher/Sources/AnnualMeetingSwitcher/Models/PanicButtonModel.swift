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
        let title = isActive ? "Blackout: ON" : "Blackout"
        let subtitle = isActive ? "Output muted" : "Stage black"
        let hint = isActive
            ? "Blackout is active: output is black and all audio is muted. Click again to restore."
            : "Emergency blackout: cut the output to black and mute all audio."

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
