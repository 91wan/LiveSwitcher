import Foundation

struct ProjectionButtonModel: Equatable {
    let hasExternalDisplay: Bool
    let isBroadcasting: Bool
    let title: String
    let subtitle: String
    let statusText: String
    let statusKind: StudioTheme.StatusKind
    let screenLabel: String
    let screenSystemImage: String
    let isEnabled: Bool
    let helpText: String
    let warningTitle: String?
    let warningMessage: String?

    static func make(
        isBroadcasting: Bool,
        hasExternalDisplay: Bool,
        safetyNotice: String?
    ) -> ProjectionButtonModel {
        if isBroadcasting {
            return ProjectionButtonModel(
                hasExternalDisplay: hasExternalDisplay,
                isBroadcasting: true,
                title: "Stop Projection",
                subtitle: "ON AIR · click to stop output",
                statusText: "ON AIR",
                statusKind: .live,
                screenLabel: hasExternalDisplay ? "外接屏幕" : "副屏状态待确认",
                screenSystemImage: hasExternalDisplay ? "display.2" : "display.trianglebadge.exclamationmark",
                isEnabled: true,
                helpText: "Stop external display projection",
                warningTitle: safetyNotice == nil ? nil : "Projection warning",
                warningMessage: safetyNotice
            )
        }

        if hasExternalDisplay {
            return ProjectionButtonModel(
                hasExternalDisplay: true,
                isBroadcasting: false,
                title: "Start Projection",
                subtitle: "Push to external display",
                statusText: "STANDBY",
                statusKind: .idle,
                screenLabel: "外接屏幕",
                screenSystemImage: "display.2",
                isEnabled: true,
                helpText: "Start external display projection",
                warningTitle: safetyNotice == nil ? nil : "Projection warning",
                warningMessage: safetyNotice
            )
        }

        return ProjectionButtonModel(
            hasExternalDisplay: false,
            isBroadcasting: false,
            title: "External Display Required",
            subtitle: "No external display detected",
            statusText: "WARN",
            statusKind: .warn,
            screenLabel: "未接副屏",
            screenSystemImage: "display",
            isEnabled: false,
            helpText: "Connect an external display before starting projection",
            warningTitle: safetyNotice == nil ? "External Display Required" : "Projection warning",
            warningMessage: safetyNotice ?? "Connect a secondary display before going on air."
        )
    }
}
