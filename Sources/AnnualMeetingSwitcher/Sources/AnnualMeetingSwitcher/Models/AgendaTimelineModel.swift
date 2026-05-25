import Foundation

struct AgendaTimelineEntry: Identifiable, Equatable {
    let id: UUID
    let title: String
    let item: ProgramItem
    let scheduledStartAt: Date
    let scheduledEndAt: Date
    let isStartInferred: Bool

    var durationMinutes: Int {
        max(1, Int((scheduledEndAt.timeIntervalSince(scheduledStartAt) / 60).rounded()))
    }

    var timeRangeText: String {
        "\(Self.formatTime(scheduledStartAt))-\(Self.formatTime(scheduledEndAt))"
    }

    private static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct AgendaTimelineModel: Equatable {
    static let defaultDuration: TimeInterval = 15 * 60

    let entries: [AgendaTimelineEntry]

    static func make(
        items: [ProgramItem],
        dayAnchor: Date,
        defaultDuration: TimeInterval = Self.defaultDuration
    ) -> AgendaTimelineModel {
        var cursor = items.first?.scheduledStartAt ?? dayAnchor
        let entries = items.map { item -> AgendaTimelineEntry in
            let isInferred = item.scheduledStartAt == nil
            let start = item.scheduledStartAt ?? cursor
            let duration = max(60, item.scheduledDuration ?? defaultDuration)
            let end = start.addingTimeInterval(duration)
            cursor = end
            return AgendaTimelineEntry(
                id: item.id,
                title: item.title,
                item: item,
                scheduledStartAt: start,
                scheduledEndAt: end,
                isStartInferred: isInferred
            )
        }
        return AgendaTimelineModel(entries: entries)
    }
}

struct AgendaScheduleStatusModel: Equatable {
    enum State: Equatable {
        case none
        case onSchedule
        case behind(minutes: Int)
        case ahead(minutes: Int)
    }

    let state: State
    let text: String
    let kind: StudioTheme.StatusKind

    static var none: AgendaScheduleStatusModel {
        AgendaScheduleStatusModel(state: .none, text: "", kind: .idle)
    }

    static func make(
        currentItem: ProgramItem?,
        switchedAt: Date?,
        now: Date = Date(),
        tolerance: TimeInterval = 90
    ) -> AgendaScheduleStatusModel {
        guard let currentItem,
              let scheduledStart = currentItem.scheduledStartAt,
              let switchedAt else {
            return .none
        }

        let expectedElapsed = now.timeIntervalSince(scheduledStart)
        let actualElapsed = now.timeIntervalSince(switchedAt)
        let drift = expectedElapsed - actualElapsed
        guard abs(drift) > tolerance else {
            return AgendaScheduleStatusModel(state: .onSchedule, text: "On schedule", kind: .ready)
        }

        let minutes = max(1, Int((abs(drift) / 60).rounded()))
        if drift > 0 {
            return AgendaScheduleStatusModel(
                state: .behind(minutes: minutes),
                text: "Behind by \(minutes) min",
                kind: .warn
            )
        }
        return AgendaScheduleStatusModel(
            state: .ahead(minutes: minutes),
            text: "Ahead \(minutes) min",
            kind: .ready
        )
    }
}

struct AgendaAutoAdvancePrompt: Equatable {
    let itemID: UUID
    let title: String
    let scheduledStartAt: Date

    var message: String {
        "Scheduled time reached. Switch to \(title)?"
    }
}

enum AgendaAutoAdvanceModel {
    static func prompt(
        isEnabled: Bool,
        programItems: [ProgramItem],
        currentProgramItem: ProgramItem?,
        now: Date = Date(),
        promptedItemIDs: Set<UUID>
    ) -> AgendaAutoAdvancePrompt? {
        guard isEnabled,
              let currentProgramItem,
              programItems.contains(where: { $0.id == currentProgramItem.id }) else {
            return nil
        }

        guard let nextIndex = ProgramQueueStore.nextPlayableIndexAfterCurrent(
            current: currentProgramItem,
            in: programItems
        ) else {
            return nil
        }

        let nextItem = programItems[nextIndex]
        guard
              let scheduledStart = nextItem.scheduledStartAt,
              scheduledStart <= now,
              !promptedItemIDs.contains(nextItem.id) else {
            return nil
        }

        return AgendaAutoAdvancePrompt(
            itemID: nextItem.id,
            title: nextItem.title,
            scheduledStartAt: scheduledStart
        )
    }
}

extension ProgramItem {
    static let agendaMarkerSubtitle = "AGENDA MARKER"

    static func agendaMarker(
        title: String,
        scheduledStartAt: Date? = nil,
        durationMinutes: Int = 15
    ) -> ProgramItem {
        ProgramItem(
            title: title,
            subtitle: agendaMarkerSubtitle,
            sourceURL: nil,
            scheduledStartAt: scheduledStartAt,
            scheduledDuration: TimeInterval(max(1, durationMinutes) * 60)
        )
    }

    static func isAgendaMarkerSubtitle(_ subtitle: String) -> Bool {
        let normalized = subtitle.uppercased()
        return normalized.contains("AGENDA MARKER") || normalized.contains("BREAK") || normalized.contains("MARKER")
    }

    var isAgendaMarker: Bool {
        Self.isAgendaMarkerSubtitle(subtitle) && sourceURL == nil
    }

    var scheduledTimeText: String? {
        guard let scheduledStartAt,
              let scheduledDuration else { return nil }
        let end = scheduledStartAt.addingTimeInterval(scheduledDuration)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: scheduledStartAt))-\(formatter.string(from: end))"
    }
}
