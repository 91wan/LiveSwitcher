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
            return AgendaScheduleStatusModel(state: .onSchedule, text: "准点", kind: .ready)
        }

        let minutes = max(1, Int((abs(drift) / 60).rounded()))
        if drift > 0 {
            return AgendaScheduleStatusModel(
                state: .behind(minutes: minutes),
                text: "落后 \(minutes) 分钟",
                kind: .warn
            )
        }
        return AgendaScheduleStatusModel(
            state: .ahead(minutes: minutes),
            text: "提前 \(minutes) 分钟",
            kind: .ready
        )
    }
}

enum AgendaReminderKind: Equatable {
    case playableProgram
    case marker
}

struct AgendaReminderPrompt: Equatable {
    let itemID: UUID
    let title: String
    let scheduledStartAt: Date
    let kind: AgendaReminderKind

    var message: String {
        switch kind {
        case .playableProgram:
            return "已到计划时间：\(title)"
        case .marker:
            return "议程提醒：\(title)"
        }
    }
}

enum AgendaReminderModel {
    static func prompt(
        isEnabled: Bool,
        programItems: [ProgramItem],
        currentProgramItem: ProgramItem?,
        now: Date = Date(),
        acknowledgedItemIDs: Set<UUID>
    ) -> AgendaReminderPrompt? {
        guard isEnabled else {
            return nil
        }

        let currentIndex = currentProgramItem.flatMap { current in
            programItems.firstIndex { $0.id == current.id }
        }
        let scanStart = currentIndex.map { $0 + 1 } ?? 0
        guard scanStart < programItems.count else { return nil }

        let candidates = programItems[scanStart...].compactMap { item -> (item: ProgramItem, scheduledStart: Date, queueIndex: Int)? in
            guard item.id != currentProgramItem?.id,
                  let scheduledStart = item.scheduledStartAt,
                  scheduledStart <= now,
                  !acknowledgedItemIDs.contains(item.id)
            else {
                return nil
            }
            let queueIndex = programItems.firstIndex { $0.id == item.id } ?? Int.max
            return (item, scheduledStart, queueIndex)
        }

        guard let nextReminder = candidates.min(by: { lhs, rhs in
            if lhs.scheduledStart != rhs.scheduledStart {
                return lhs.scheduledStart < rhs.scheduledStart
            }
            return lhs.queueIndex < rhs.queueIndex
        }) else { return nil }

        return AgendaReminderPrompt(
            itemID: nextReminder.item.id,
            title: nextReminder.item.title,
            scheduledStartAt: nextReminder.scheduledStart,
            kind: nextReminder.item.isAgendaMarker ? .marker : .playableProgram
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
