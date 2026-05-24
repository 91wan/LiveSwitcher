import Foundation

struct LowerThirdPreset: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var subtitle: String
    var orderIndex: Int

    static func make(
        id: UUID = UUID(),
        name: String,
        subtitle: String,
        orderIndex: Int
    ) -> LowerThirdPreset? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        return LowerThirdPreset(
            id: id,
            name: trimmedName,
            subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
            orderIndex: max(0, orderIndex)
        )
    }

    static func normalized(_ presets: [LowerThirdPreset]) -> [LowerThirdPreset] {
        presets
            .compactMap { preset in
                LowerThirdPreset.make(
                    id: preset.id,
                    name: preset.name,
                    subtitle: preset.subtitle,
                    orderIndex: preset.orderIndex
                )
            }
            .sorted {
                if $0.orderIndex == $1.orderIndex {
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
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
