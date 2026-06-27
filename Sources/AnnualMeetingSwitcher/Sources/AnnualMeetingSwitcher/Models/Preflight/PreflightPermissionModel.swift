import Foundation

extension LivePreflightCheck {
    static func displayCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        if snapshot.hasExternalDisplay {
            return LivePreflightCheck(
                id: "display.external",
                group: .display,
                status: .pass,
                title: "外接显示器",
                message: "已检测到外接显示器，可以准备投射。"
            )
        }

        return LivePreflightCheck(
            id: "display.external",
            group: .display,
            status: .fail,
            title: "外接显示器",
            message: "需要硬件：未检测到外接显示器，请勿投射。",
            actionLabel: "需要硬件",
            actionKind: .needsHardware
        )
    }

    static func broadcastCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        if snapshot.isBroadcasting && !snapshot.hasExternalDisplay {
            return LivePreflightCheck(
                id: "display.broadcast",
                group: .display,
                status: .fail,
                title: "投射状态",
                message: "投射状态为开启，但未检测到外接显示器。开场前请停止投射。",
                actionLabel: "需要硬件",
                actionKind: .needsHardware
            )
        }

        if snapshot.isBroadcasting {
            return LivePreflightCheck(
                id: "display.broadcast",
                group: .display,
                status: .pass,
                title: "投射状态",
                message: "当前正在外接屏投射。"
            )
        }

        if let notice = snapshot.broadcastSafetyNotice, !notice.isEmpty {
            return LivePreflightCheck(
                id: "display.broadcast",
                group: .display,
                status: .warn,
                title: "投射状态",
                message: "投射未开启。最近提示：\(notice)",
                actionLabel: "打开节目单",
                actionKind: .openPreview
            )
        }

        return LivePreflightCheck(
            id: "display.broadcast",
            group: .display,
            status: .warn,
            title: "投射状态",
            message: "投射未开启。直播前请确认外接屏。",
            actionLabel: "打开节目单",
            actionKind: .openPreview
        )
    }

    static func pptCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        let source = snapshot.currentProgramSource
        let pageableSources: Set<String> = ["HTML", "Keynote", "PPTX", "Active Keynote Deck"]
        let deckSources: Set<String> = ["Keynote", "PPTX", "Active Keynote Deck"]
        let isPageableSource = source.map { pageableSources.contains($0) } ?? false
        let isDeckSource = source.map { deckSources.contains($0) } ?? false

        let status: LivePreflightStatus
        let message: String
        if snapshot.isPageInterceptEnabled {
            if isPageableSource {
                status = .pass
                message = "PPT 模式已针对可翻页信号源开启。翻页笔按键会用于演示控制。"
            } else {
                status = .warn
                message = "PPT 模式已开启，但当前节目不是可翻页信号源。除非需要接管翻页笔，否则请关闭。"
            }
        } else if isDeckSource {
            status = .warn
            message = "当前载入演示信号源，但 PPT 模式关闭。直播前请确认是否需要接管翻页笔。"
        } else {
            status = .pass
            message = "PPT 模式关闭。仅在需要接管翻页笔时开启。"
        }

        return LivePreflightCheck(
            id: "controls.ppt",
            group: .controls,
            status: status,
            title: "PPT 模式",
            message: message,
            actionLabel: "人工复核",
            actionKind: .manualReview
        )
    }
}
