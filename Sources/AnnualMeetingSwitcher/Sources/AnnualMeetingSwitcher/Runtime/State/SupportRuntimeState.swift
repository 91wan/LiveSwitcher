import Foundation

struct SupportRuntimeState: Equatable {
    var events: [LiveSupportEvent] = []
    var coalescedCounts: [String: Int] = [:]
    var eventLimit = 80

    @discardableResult
    mutating func record(event: LiveSupportEvent) -> LiveSupportEvent? {
        record(kind: event.kind, detail: event.detail, at: event.timestamp)
    }

    @discardableResult
    mutating func record(kind: LiveSupportEventKind, detail: String, at date: Date) -> LiveSupportEvent? {
        let baseDetail = LiveSupportRedactor.safeEventDetail(detail)
        let key = "\(kind.rawValue)|\(baseDetail)"

        if shouldCoalesce(kind),
           let index = events.firstIndex(where: { $0.kind == kind && supportEventBaseDetail($0.detail) == baseDetail }) {
            let existing = events.remove(at: index)
            let nextCount = supportEventCoalescedCount(existing.detail) + 1
            coalescedCounts[key] = nextCount
            let accepted = LiveSupportEvent(
                timestamp: date,
                kind: kind,
                detail: "\(baseDetail),count=\(nextCount),lastSeen=\(Self.isoString(date))"
            )
            events.append(accepted)
            trimToLimit()
            return events.contains(accepted) ? accepted : nil
        }

        coalescedCounts[key] = 1
        let accepted = LiveSupportEvent(timestamp: date, kind: kind, detail: baseDetail)
        events.append(accepted)
        trimToLimit()
        return events.contains(accepted) ? accepted : nil
    }

    private mutating func trimToLimit() {
        while events.count > eventLimit {
            guard let indexToRemove = events.indices.min(by: { lhs, rhs in
                let lhsPriority = LiveSupportEventPriorityPolicy.priority(for: events[lhs].kind)
                let rhsPriority = LiveSupportEventPriorityPolicy.priority(for: events[rhs].kind)
                if lhsPriority == rhsPriority {
                    return events[lhs].timestamp < events[rhs].timestamp
                }
                return lhsPriority < rhsPriority
            }) else {
                return
            }
            events.remove(at: indexToRemove)
        }
    }

    private func shouldCoalesce(_ kind: LiveSupportEventKind) -> Bool {
        switch kind {
        case .appleScriptFailed, .pageInterceptWPSNotRunning, .pageInterceptForwardedToWPS:
            return true
        default:
            return false
        }
    }

    private func supportEventBaseDetail(_ detail: String) -> String {
        guard let countRange = detail.range(of: ",count=") else {
            return detail
        }
        return String(detail[..<countRange.lowerBound])
    }

    private func supportEventCoalescedCount(_ detail: String) -> Int {
        guard let countRange = detail.range(of: ",count=") else {
            return 1
        }
        let countStart = countRange.upperBound
        let countEnd = detail[countStart...].firstIndex(of: ",") ?? detail.endIndex
        return Int(detail[countStart..<countEnd]) ?? 1
    }

    private static func isoString(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
