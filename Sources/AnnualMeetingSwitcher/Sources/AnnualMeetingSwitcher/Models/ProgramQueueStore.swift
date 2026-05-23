import Foundation

enum ProgramQueueStore {
    static func persistentProgramItems(from items: [ProgramItem]) -> [ProgramItem] {
        items.filter { $0.sourceURL != nil }
    }

    static func restoredProgramItems(
        paths: [String],
        titles: [String],
        subtitles: [String],
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> [ProgramItem] {
        paths.enumerated().compactMap { index, path in
            guard fileExists(path) else { return nil }
            let url = URL(fileURLWithPath: path)
            let title = index < titles.count ? titles[index] : url.deletingPathExtension().lastPathComponent
            let subtitle = index < subtitles.count ? subtitles[index] : url.pathExtension.uppercased()
            return ProgramItem(title: title, subtitle: subtitle, sourceURL: url)
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
}
