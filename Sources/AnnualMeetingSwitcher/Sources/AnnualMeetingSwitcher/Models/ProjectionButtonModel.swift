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
        if isBroadcasting && !hasExternalDisplay {
            return ProjectionButtonModel(
                hasExternalDisplay: false,
                isBroadcasting: true,
                title: "停止投射",
                subtitle: "副屏丢失 · 点击停止输出",
                statusText: "副屏丢失",
                statusKind: .fail,
                screenLabel: "副屏已断开",
                screenSystemImage: "display.trianglebadge.exclamationmark",
                isEnabled: true,
                helpText: "停止投射并重新连接外接显示器",
                warningTitle: "副屏丢失",
                warningMessage: "投射状态仍为开启，但没有检测到外接显示器。请停止投射并重新连接硬件。"
            )
        }

        if isBroadcasting {
            return ProjectionButtonModel(
                hasExternalDisplay: hasExternalDisplay,
                isBroadcasting: true,
                title: "停止投射",
                subtitle: "直播中 · 点击停止输出",
                statusText: "直播",
                statusKind: .live,
                screenLabel: "外接屏幕",
                screenSystemImage: "display.2",
                isEnabled: true,
                helpText: "停止外接屏投射",
                warningTitle: safetyNotice == nil ? nil : "投射警告",
                warningMessage: safetyNotice
            )
        }

        if hasExternalDisplay {
            return ProjectionButtonModel(
                hasExternalDisplay: true,
                isBroadcasting: false,
                title: "开始投射",
                subtitle: "输出到外接屏",
                statusText: "待机",
                statusKind: .idle,
                screenLabel: "外接屏幕",
                screenSystemImage: "display.2",
                isEnabled: true,
                helpText: "开始外接屏投射",
                warningTitle: safetyNotice == nil ? nil : "投射警告",
                warningMessage: safetyNotice
            )
        }

        return ProjectionButtonModel(
            hasExternalDisplay: false,
            isBroadcasting: false,
            title: "需要外接屏",
            subtitle: "未检测到外接显示器",
            statusText: "警告",
            statusKind: .warn,
            screenLabel: "未接副屏",
            screenSystemImage: "display",
            isEnabled: false,
            helpText: "连接外接显示器后才能开始投射",
            warningTitle: safetyNotice == nil ? "需要外接屏" : "投射警告",
            warningMessage: safetyNotice ?? "直播前请先连接副屏。"
        )
    }
}
