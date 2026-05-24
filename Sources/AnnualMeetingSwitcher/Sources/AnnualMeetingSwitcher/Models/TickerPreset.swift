import Foundation

struct TickerPreset: Identifiable, Codable, Equatable {
    static let defaultText = "Welcome · The program will begin shortly"

    let id: UUID
    var text: String
    var speedIndex: Int
    var orderIndex: Int

    static func make(
        id: UUID = UUID(),
        text: String,
        speedIndex: Int,
        orderIndex: Int
    ) -> TickerPreset? {
        guard OverlayUIState.tickerDisabledReason(text: text, isLive: false) == nil else {
            return nil
        }

        let maxSpeedIndex = OverlaySpeedSelection.options.index(before: OverlaySpeedSelection.options.endIndex)
        let clampedSpeedIndex = min(max(speedIndex, OverlaySpeedSelection.options.startIndex), maxSpeedIndex)
        return TickerPreset(
            id: id,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            speedIndex: clampedSpeedIndex,
            orderIndex: max(0, orderIndex)
        )
    }

    static func normalized(_ presets: [TickerPreset]) -> [TickerPreset] {
        presets
            .compactMap { preset in
                TickerPreset.make(
                    id: preset.id,
                    text: preset.text,
                    speedIndex: preset.speedIndex,
                    orderIndex: preset.orderIndex
                )
            }
            .sorted {
                if $0.orderIndex == $1.orderIndex {
                    return $0.text.localizedStandardCompare($1.text) == .orderedAscending
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
