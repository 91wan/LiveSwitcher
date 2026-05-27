import Foundation

struct SourceRailRowLabelModel: Equatable {
    let text: String
    let accessibilityLabel: String

    static func make(
        queuePosition: Int,
        queueRole: QueueRole,
        sourceLabel: String
    ) -> SourceRailRowLabelModel {
        let indexLabel = ordinal(queuePosition)
        let roleText = roleSegment(queueRole)
        let segments = ([indexLabel, roleText, sourceLabel] as [String?]).compactMap { $0 }
        let accessibilitySegments = (["第 \(max(queuePosition, 0)) 项", roleText, sourceLabel] as [String?]).compactMap { $0 }

        return SourceRailRowLabelModel(
            text: segments.joined(separator: " · "),
            accessibilityLabel: accessibilitySegments.joined(separator: "，")
        )
    }

    private static func roleSegment(_ role: QueueRole) -> String? {
        switch role {
        case .current:
            return "正在播"
        case .next:
            return "下一项"
        case .queued:
            return nil
        }
    }

    private static func ordinal(_ value: Int) -> String {
        switch value {
        case 1: return "①"
        case 2: return "②"
        case 3: return "③"
        case 4: return "④"
        case 5: return "⑤"
        case 6: return "⑥"
        case 7: return "⑦"
        case 8: return "⑧"
        case 9: return "⑨"
        case 10: return "⑩"
        case 11: return "⑪"
        case 12: return "⑫"
        case 13: return "⑬"
        case 14: return "⑭"
        case 15: return "⑮"
        case 16: return "⑯"
        case 17: return "⑰"
        case 18: return "⑱"
        case 19: return "⑲"
        case 20: return "⑳"
        default: return "\(value)"
        }
    }
}
