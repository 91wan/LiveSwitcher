import Foundation

struct SourceRailRowLabelModel: Equatable {
    let numberText: String
    let detailText: String
    let text: String
    let accessibilityLabel: String

    static func make(
        queuePosition: Int,
        queueRole: QueueRole,
        sourceLabel: String
    ) -> SourceRailRowLabelModel {
        let numberText = ordinal(queuePosition)
        let roleText = roleSegment(queueRole)
        let detailText = ([roleText, sourceLabel] as [String?]).compactMap { $0 }.joined(separator: " · ")
        let segments = ([numberText, roleText, sourceLabel] as [String?]).compactMap { $0 }
        let accessibilitySegments = (["第 \(max(queuePosition, 0)) 项", roleText, sourceLabel] as [String?]).compactMap { $0 }

        return SourceRailRowLabelModel(
            numberText: numberText,
            detailText: detailText,
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
        "\(value)"
    }
}
