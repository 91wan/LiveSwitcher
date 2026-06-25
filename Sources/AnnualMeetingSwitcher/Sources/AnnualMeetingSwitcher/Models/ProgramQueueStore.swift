import Foundation

enum ProgramQueueStore {
    static func persistentProgramItems(from items: [ProgramItem]) -> [ProgramItem] {
        items.filter { $0.sourceURL != nil || $0.isAgendaMarker }
    }

    static func restoredProgramItems(
        paths: [String],
        titles: [String],
        subtitles: [String],
        scheduledStarts: [String] = [],
        scheduledDurations: [String] = [],
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> [ProgramItem] {
        paths.enumerated().compactMap { index, path in
            let subtitle = index < subtitles.count ? subtitles[index] : ""
            let scheduledStart = decodedDate(at: index, in: scheduledStarts)
            let scheduledDuration = decodedDuration(at: index, in: scheduledDurations)

            if path.isEmpty, ProgramItem.isAgendaMarkerSubtitle(subtitle) {
                let title = index < titles.count ? titles[index] : "议程标记"
                return ProgramItem(
                    title: title,
                    subtitle: subtitle,
                    sourceURL: nil,
                    scheduledStartAt: scheduledStart,
                    scheduledDuration: scheduledDuration
                )
            }

            guard fileExists(path) else { return nil }
            let url = URL(fileURLWithPath: path)
            let title = index < titles.count ? titles[index] : url.deletingPathExtension().lastPathComponent
            let restoredSubtitle = subtitle.isEmpty ? url.pathExtension.uppercased() : subtitle
            return ProgramItem(
                title: title,
                subtitle: restoredSubtitle,
                sourceURL: url,
                scheduledStartAt: scheduledStart,
                scheduledDuration: scheduledDuration
            )
        }
    }

    static func nextVideoAfterCurrent(
        current: ProgramItem?,
        in items: [ProgramItem]
    ) -> ProgramItem? {
        guard let current,
              let currentIndex = items.firstIndex(where: { $0.id == current.id }) else {
            return nil
        }

        let nextIndex = currentIndex + 1
        guard items.indices.contains(nextIndex) else { return nil }

        let nextItem = items[nextIndex]
        return nextItem.isVideoMedia ? nextItem : nil
    }

    static func nextPlayableIndexAfterCurrent(
        current: ProgramItem?,
        in items: [ProgramItem]
    ) -> Int? {
        let searchStart: Array<ProgramItem>.Index
        if let current,
           let currentIndex = items.firstIndex(where: { $0.id == current.id }) {
            searchStart = items.index(after: currentIndex)
        } else {
            searchStart = items.startIndex
        }

        guard searchStart < items.endIndex else { return nil }
        return items[searchStart...].firstIndex { !$0.isAgendaMarker }
    }

    static func nextPlayableAfterCurrent(
        current: ProgramItem?,
        in items: [ProgramItem]
    ) -> ProgramItem? {
        guard let index = nextPlayableIndexAfterCurrent(current: current, in: items) else {
            return nil
        }
        return items[index]
    }

    static func encodedScheduleStarts(for items: [ProgramItem]) -> [String] {
        items.map { item in
            item.scheduledStartAt.map { String($0.timeIntervalSince1970) } ?? ""
        }
    }

    static func encodedScheduleDurations(for items: [ProgramItem]) -> [String] {
        items.map { item in
            item.scheduledDuration.map { String($0) } ?? ""
        }
    }

    private static func decodedDate(at index: Int, in values: [String]) -> Date? {
        guard index < values.count,
              let interval = TimeInterval(values[index]),
              interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    private static func decodedDuration(at index: Int, in values: [String]) -> TimeInterval? {
        guard index < values.count,
              let duration = TimeInterval(values[index]),
              duration > 0 else { return nil }
        return duration
    }
}
