import SwiftUI

struct SignalSourceRowStyleModel {
    let backgroundFill: Color
    let borderColor: Color
    let contentOpacity: Double
    let statusTint: Color
    let currentRowControlTint: Color

    static func make(
        queueRole: QueueRole,
        isBroadcasting: Bool,
        isHovered: Bool
    ) -> SignalSourceRowStyleModel {
        SignalSourceRowStyleModel(
            backgroundFill: backgroundFill(
                queueRole: queueRole,
                isBroadcasting: isBroadcasting,
                isHovered: isHovered
            ),
            borderColor: borderColor(
                queueRole: queueRole,
                isBroadcasting: isBroadcasting,
                isHovered: isHovered
            ),
            contentOpacity: contentOpacity(queueRole: queueRole),
            statusTint: statusTint(queueRole: queueRole),
            currentRowControlTint: isBroadcasting ? StudioTheme.Tone.live : StudioTheme.Action.primary
        )
    }

    private static func backgroundFill(
        queueRole: QueueRole,
        isBroadcasting: Bool,
        isHovered: Bool
    ) -> Color {
        switch queueRole {
        case .current:
            return (isBroadcasting ? StudioTheme.Tone.live : StudioTheme.Action.primary).opacity(0.08)
        case .next:
            return StudioTheme.Tone.warn.opacity(isHovered ? 0.11 : 0.07)
        case .queued:
            return isHovered ? StudioTheme.Surface.raised.opacity(0.8) : Color.clear
        }
    }

    private static func borderColor(
        queueRole: QueueRole,
        isBroadcasting: Bool,
        isHovered: Bool
    ) -> Color {
        switch queueRole {
        case .current:
            return isBroadcasting ? StudioTheme.borderCritical : StudioTheme.borderActive
        case .next:
            return StudioTheme.Tone.warn.opacity(0.24)
        case .queued:
            return isHovered ? StudioTheme.borderSubtle : Color.clear
        }
    }

    private static func contentOpacity(queueRole: QueueRole) -> Double {
        switch queueRole {
        case .current:
            return 1
        case .next:
            return 0.96
        case .queued:
            return 0.82
        }
    }

    private static func statusTint(queueRole: QueueRole) -> Color {
        switch queueRole {
        case .current:
            return .secondary
        case .next:
            return StudioTheme.Tone.warn
        case .queued:
            return .secondary
        }
    }
}
