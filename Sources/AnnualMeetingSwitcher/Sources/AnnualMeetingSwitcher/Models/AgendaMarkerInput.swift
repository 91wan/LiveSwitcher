import Foundation

struct AgendaMarkerInput: Equatable {
    static let maxTitleCharacterCount = 40
    static let minDuration: TimeInterval = 60
    static let maxDuration: TimeInterval = 999 * 60
    static let defaultDuration: TimeInterval = AgendaTimelineModel.defaultDuration

    var title: String
    var scheduledStartAt: Date?
    var duration: TimeInterval

    func normalized() -> AgendaMarkerInput? {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty,
              normalizedTitle.count <= Self.maxTitleCharacterCount else {
            return nil
        }

        let finiteDuration = duration.isFinite ? duration : Self.defaultDuration
        let normalizedDuration = min(max(finiteDuration, Self.minDuration), Self.maxDuration)
        return AgendaMarkerInput(
            title: normalizedTitle,
            scheduledStartAt: scheduledStartAt,
            duration: normalizedDuration
        )
    }

    static func initial(title: String = "") -> AgendaMarkerInput {
        AgendaMarkerInput(title: title, scheduledStartAt: nil, duration: defaultDuration)
    }

    static func fromMarker(_ item: ProgramItem) -> AgendaMarkerInput {
        AgendaMarkerInput(
            title: item.title,
            scheduledStartAt: item.scheduledStartAt,
            duration: item.scheduledDuration ?? defaultDuration
        )
    }
}
