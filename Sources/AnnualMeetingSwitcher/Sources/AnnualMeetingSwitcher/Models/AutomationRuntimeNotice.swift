import Foundation

enum AutomationRuntimeNoticeSeverity: Equatable {
    case warn
    case fail
}

enum AutomationRuntimeNoticeAction: Equatable {
    case openPreflight
    case openHelp
    case openSystemSettingsAccessibility

    var label: String {
        switch self {
        case .openPreflight:
            return "打开检查"
        case .openHelp:
            return "查看帮助"
        case .openSystemSettingsAccessibility:
            return "打开权限设置"
        }
    }
}

struct AutomationRuntimeNotice: Equatable, Identifiable {
    let id: UUID
    let action: String
    let title: String
    let message: String
    let severity: AutomationRuntimeNoticeSeverity
    let primaryAction: AutomationRuntimeNoticeAction?
    let createdAt: Date
    let expiresAt: Date?

    init(
        id: UUID = UUID(),
        action: String,
        title: String,
        message: String,
        severity: AutomationRuntimeNoticeSeverity,
        primaryAction: AutomationRuntimeNoticeAction?,
        createdAt: Date = Date(),
        expiresAfter: TimeInterval?
    ) {
        self.id = id
        self.action = action
        self.title = title
        self.message = message
        self.severity = severity
        self.primaryAction = primaryAction
        self.createdAt = createdAt
        self.expiresAt = expiresAfter.map { createdAt.addingTimeInterval($0) }
    }
}

enum AutomationRuntimeNoticePolicy {
    static func make(action: String, createdAt: Date = Date()) -> AutomationRuntimeNotice {
        let copy = copy(for: action)
        return AutomationRuntimeNotice(
            action: action,
            title: copy.title,
            message: copy.message,
            severity: copy.severity,
            primaryAction: copy.primaryAction,
            createdAt: createdAt,
            expiresAfter: copy.expiresAfter
        )
    }

    private static func copy(for action: String) -> (
        title: String,
        message: String,
        severity: AutomationRuntimeNoticeSeverity,
        primaryAction: AutomationRuntimeNoticeAction?,
        expiresAfter: TimeInterval?
    ) {
        if action.hasPrefix("program.source.missing") {
            return (
                "节目文件不存在",
                "请确认素材仍在原位置，或重新导入该节目。",
                .warn,
                .openPreflight,
                10
            )
        }

        if action.hasPrefix("wps.page") {
            return (
                "演示软件未运行",
                "请先打开 WPS/Keynote 并开始放映。",
                .fail,
                .openPreflight,
                14
            )
        }

        if action.hasPrefix("wps.open") {
            return (
                "WPS 打开失败",
                "请确认 WPS 已安装，或改用 Keynote 文件。",
                .fail,
                .openPreflight,
                14
            )
        }

        if action.contains("next-slide") || action.contains("previous-slide") || action.contains("page") {
            return (
                "翻页未发送",
                "请确认演示窗口正在放映，或关闭 PPT 模式。",
                .warn,
                .openPreflight,
                10
            )
        }

        if action.contains("stop") {
            return (
                "演示停止失败",
                "请确认演示软件仍在运行并允许 LiveSwitcher 控制。",
                .warn,
                .openPreflight,
                10
            )
        }

        if action.contains("scan") {
            return (
                "演示扫描失败",
                "请确认 Keynote 已打开并允许 LiveSwitcher 控制。",
                .warn,
                .openPreflight,
                10
            )
        }

        if action.hasPrefix("keynote") {
            return (
                "Keynote 放映失败",
                "请确认 Keynote 已打开并允许 LiveSwitcher 控制。",
                .fail,
                .openPreflight,
                14
            )
        }

        return (
            "演示自动化失败",
            "请检查演示软件状态和自动化权限。",
            .warn,
            .openPreflight,
            10
        )
    }
}
