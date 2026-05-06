import Foundation

struct LiveSafetyCockpitState: Equatable {
    var summary: LivePreflightSummary
    var priorityChecks: [LivePreflightCheck]
    var sections: [LiveSafetyCockpitSection]
    var recentEvents: [LiveSafetyCockpitEventRow]
    var safeActionCount: Int
}

struct LiveSafetyCockpitSection: Identifiable, Equatable {
    var id: String { group.rawValue }
    var group: LivePreflightGroup
    var title: String
    var checks: [LivePreflightCheck]
}

struct LiveSafetyCockpitEventRow: Identifiable, Equatable {
    var id: String
    var timestamp: String
    var kind: String
    var detail: String
}

enum LiveSafetyCockpit {
    static func make(
        snapshot: LivePreflightSnapshot,
        checks: [LivePreflightCheck],
        events: [LiveSupportEvent]
    ) -> LiveSafetyCockpitState {
        let priorityChecks = checks.sorted { lhs, rhs in
            let lhsRank = rank(lhs.status)
            let rhsRank = rank(rhs.status)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            return checkOrder(checks, lhs) < checkOrder(checks, rhs)
        }

        let sections = LivePreflightGroup.allCases.compactMap { group -> LiveSafetyCockpitSection? in
            let groupChecks = priorityChecks.filter { $0.group == group }
            guard !groupChecks.isEmpty else { return nil }
            return LiveSafetyCockpitSection(
                group: group,
                title: group.displayTitle,
                checks: groupChecks
            )
        }

        let recentSupportEvents = Array(events.suffix(12))
        let firstRecentSequence = events.count - recentSupportEvents.count

        return LiveSafetyCockpitState(
            summary: LivePreflightSummary.make(from: checks),
            priorityChecks: priorityChecks,
            sections: sections,
            recentEvents: recentSupportEvents.enumerated().map { offset, event in
                eventRow(event, sequence: firstRecentSequence + offset)
            },
            safeActionCount: checks.filter { check in
                check.actionKind == .clearOverlays || check.actionKind == .turnOffPanic
            }.count
        )
    }

    private static func rank(_ status: LivePreflightStatus) -> Int {
        switch status {
        case .fail:
            return 0
        case .warn:
            return 1
        case .pass:
            return 2
        }
    }

    private static func checkOrder(_ checks: [LivePreflightCheck], _ check: LivePreflightCheck) -> Int {
        checks.firstIndex(where: { $0.id == check.id }) ?? Int.max
    }

    private static func eventRow(_ event: LiveSupportEvent, sequence: Int) -> LiveSafetyCockpitEventRow {
        LiveSafetyCockpitEventRow(
            id: "\(isoString(event.timestamp))-\(event.kind.rawValue)-\(sequence)",
            timestamp: isoString(event.timestamp),
            kind: event.kind.rawValue,
            detail: LiveSupportRedactor.safeText(event.detail)
        )
    }

    private static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}
