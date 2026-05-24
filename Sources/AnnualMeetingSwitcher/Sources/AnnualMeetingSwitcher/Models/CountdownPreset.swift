import Foundation

struct CountdownPreset: Identifiable, Codable, Equatable {
    static let defaultTitle = "活动即将开始"

    let id: UUID
    var title: String
    var totalSeconds: Int
    var orderIndex: Int

    static func make(
        id: UUID = UUID(),
        title: String,
        totalSeconds: Int,
        orderIndex: Int
    ) -> CountdownPreset? {
        guard OverlayUIState.countdownDisabledReason(totalSeconds: totalSeconds, isLive: false) == nil else {
            return nil
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return CountdownPreset(
            id: id,
            title: trimmedTitle.isEmpty ? defaultTitle : trimmedTitle,
            totalSeconds: totalSeconds,
            orderIndex: max(0, orderIndex)
        )
    }

    static func normalized(_ presets: [CountdownPreset]) -> [CountdownPreset] {
        presets
            .compactMap { preset in
                CountdownPreset.make(
                    id: preset.id,
                    title: preset.title,
                    totalSeconds: preset.totalSeconds,
                    orderIndex: preset.orderIndex
                )
            }
            .sorted {
                if $0.orderIndex == $1.orderIndex {
                    return $0.title.localizedStandardCompare($1.title) == .orderedAscending
                }
                return $0.orderIndex < $1.orderIndex
            }
            .enumerated()
            .map { index, preset in
                var normalizedPreset = preset
                normalizedPreset.orderIndex = index
                return normalizedPreset
            }
    }
}
