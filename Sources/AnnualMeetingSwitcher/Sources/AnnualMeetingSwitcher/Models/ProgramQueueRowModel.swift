import Foundation

enum QueueRole {
    case current
    case next
    case queued
}

struct ProgramQueueRowModel: Equatable {
    enum ControlStyle: Equatable {
        case media
        case html
        case presentation
        case unsupported
        case none
    }

    let item: ProgramItem
    let queuePosition: Int
    let queueRole: QueueRole
    let isBroadcasting: Bool
    let isPlaying: Bool

    var controlStyle: ControlStyle {
        guard queueRole == .current else { return .none }
        switch item.sourceKind {
        case .media:
            return .media
        case .html:
            return .html
        case .keynote, .pptx, .activeDeck:
            return .presentation
        case .agendaMarker, .unsupported:
            return .unsupported
        }
    }

    var showsProgressSlider: Bool {
        controlStyle == .media
    }

    var queueBadgeText: String {
        switch queueRole {
        case .current:
            return isBroadcasting ? "ON AIR" : "PREVIEW"
        case .next:
            return "NEXT"
        case .queued:
            return "\(queuePosition)"
        }
    }

    var stateBadgeText: String? {
        switch queueRole {
        case .current:
            return queueBadgeText
        case .next:
            return "NEXT"
        case .queued:
            return nil
        }
    }

    var controlRailLabel: String {
        isBroadcasting ? "ON AIR 主控" : "PREVIEW 主控"
    }

    var primarySystemName: String {
        switch controlStyle {
        case .media:
            return isPlaying ? "pause.fill" : "play.fill"
        case .html:
            return "xmark.circle.fill"
        case .presentation:
            return "stop.fill"
        case .unsupported, .none:
            return "circle"
        }
    }

    var primaryAccessibilityLabel: String {
        switch controlStyle {
        case .media:
            return isPlaying ? "Pause current media" : "Play current media"
        case .html:
            return "End current HTML presentation"
        case .presentation:
            return "Stop current presentation"
        case .unsupported, .none:
            return ""
        }
    }

    var primaryHelp: String {
        switch controlStyle {
        case .media:
            return "暂停 / 播放"
        case .html:
            return "结束 HTML 展示 · 回到壁纸"
        case .presentation:
            return "停止当前演示"
        case .unsupported, .none:
            return ""
        }
    }
}
