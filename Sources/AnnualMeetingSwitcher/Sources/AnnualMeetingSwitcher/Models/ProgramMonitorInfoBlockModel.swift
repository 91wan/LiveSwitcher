import Foundation

struct ProgramMonitorInfoBlockModel: Equatable {
    let title: String
    let value: String
    let subtitle: String
    let badgeText: String
    let status: StudioTheme.StatusKind

    var accessibilityLabel: String {
        "\(title): \(value), \(subtitle), \(badgeText)"
    }

    static func current(
        item: ProgramItem?,
        isBroadcasting: Bool,
        isPlaying: Bool,
        isHTMLLoaded: Bool
    ) -> ProgramMonitorInfoBlockModel {
        guard let item else {
            return ProgramMonitorInfoBlockModel(
                title: "当前",
                value: "无节目",
                subtitle: "待机",
                badgeText: "空",
                status: .idle
            )
        }

        let subtitle: String
        if isHTMLLoaded {
            subtitle = "HTML 已载入"
        } else if isPlaying {
            subtitle = "媒体播放中"
        } else {
            subtitle = item.subtitle.uppercased()
        }

        return ProgramMonitorInfoBlockModel(
            title: "当前",
            value: item.title,
            subtitle: subtitle,
            badgeText: isBroadcasting ? "直播" : "预览",
            status: isBroadcasting ? .live : .idle
        )
    }

    static func next(item: ProgramItem?) -> ProgramMonitorInfoBlockModel {
        guard let item else {
            return ProgramMonitorInfoBlockModel(
                title: "下一项",
                value: "无",
                subtitle: "队列为空",
                badgeText: "空",
                status: .idle
            )
        }

        return ProgramMonitorInfoBlockModel(
            title: "下一项",
            value: item.title,
            subtitle: item.subtitle.uppercased(),
            badgeText: "下一项",
            status: .ready
        )
    }
}

struct ProgramMonitorStateModel: Equatable {
    let label: String
    let kind: StudioTheme.StatusKind

    static func make(isBroadcasting: Bool, currentItem: ProgramItem?) -> ProgramMonitorStateModel {
        if isBroadcasting {
            return ProgramMonitorStateModel(label: "直播", kind: .live)
        }
        if currentItem != nil {
            return ProgramMonitorStateModel(label: "预览", kind: .idle)
        }
        return ProgramMonitorStateModel(label: "待机", kind: .idle)
    }
}

struct ProgramMonitorChromeLayoutModel: Equatable {
    enum Variant: Equatable {
        case full
        case compact
        case stateOnly
    }

    let variant: Variant

    var showsFullInlineStatus: Bool {
        variant == .full
    }

    var showsCompactInlineStatus: Bool {
        variant == .compact
    }

    static func make(width: Double) -> ProgramMonitorChromeLayoutModel {
        if width >= 520 {
            return ProgramMonitorChromeLayoutModel(variant: .full)
        }
        if width >= 320 {
            return ProgramMonitorChromeLayoutModel(variant: .compact)
        }
        return ProgramMonitorChromeLayoutModel(variant: .stateOnly)
    }
}
