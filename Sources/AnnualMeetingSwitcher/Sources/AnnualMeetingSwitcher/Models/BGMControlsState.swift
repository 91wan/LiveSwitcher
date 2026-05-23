import Foundation

struct BGMControlsState: Equatable {
    let canSeekToBeginning: Bool
    let canSkipPrevious: Bool
    let canPlay: Bool
    let canSkipNext: Bool
    let playDisabledReason: String?
    let skipDisabledReason: String?
    let seekDisabledReason: String?

    static func make(items: [BGMItem], currentItem: BGMItem?) -> BGMControlsState {
        let hasLibraryItems = !items.isEmpty
        let categoryItems: [BGMItem]
        if let currentItem {
            categoryItems = items.filter { $0.category == currentItem.category }
        } else {
            categoryItems = []
        }
        let canSkip = currentItem != nil && categoryItems.count >= 2

        return BGMControlsState(
            canSeekToBeginning: currentItem != nil,
            canSkipPrevious: canSkip,
            canPlay: currentItem != nil || hasLibraryItems,
            canSkipNext: canSkip,
            playDisabledReason: hasLibraryItems ? nil : "Add music before starting BGM.",
            skipDisabledReason: canSkip ? nil : "At least two tracks in the current category are required.",
            seekDisabledReason: currentItem == nil ? "Select or start a BGM track first." : nil
        )
    }
}
