import Foundation

struct AutomationRuntimeNotice: Equatable, Identifiable {
    let id: UUID
    let action: String
    let title: String
    let message: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        action: String,
        title: String,
        message: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.action = action
        self.title = title
        self.message = message
        self.createdAt = createdAt
    }
}

enum AutomationRuntimeNoticePolicy {
    static func make(action: String, createdAt: Date = Date()) -> AutomationRuntimeNotice {
        let copy = copy(for: action)
        return AutomationRuntimeNotice(
            action: action,
            title: copy.title,
            message: copy.message,
            createdAt: createdAt
        )
    }

    private static func copy(for action: String) -> (title: String, message: String) {
        if action.hasPrefix("wps.open") {
            return (
                "WPS 打开失败",
                "请确认 WPS 已安装，或改用 Keynote 文件。"
            )
        }

        if action.contains("next-slide") || action.contains("previous-slide") || action.contains("page") {
            return (
                "翻页失败",
                "请确认当前演示软件正在放映。"
            )
        }

        if action.contains("stop") {
            return (
                "演示停止失败",
                "请确认演示软件仍在运行并允许 LiveSwitcher 控制。"
            )
        }

        if action.contains("scan") {
            return (
                "演示扫描失败",
                "请确认 Keynote 已打开并允许 LiveSwitcher 控制。"
            )
        }

        if action.hasPrefix("keynote") {
            return (
                "Keynote 放映失败",
                "请确认 Keynote 已打开并允许 LiveSwitcher 控制。"
            )
        }

        return (
            "演示自动化失败",
            "请检查演示软件状态和自动化权限。"
        )
    }
}
