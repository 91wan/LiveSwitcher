import Foundation

struct BGMControlsState: Equatable {
    let canSeekToBeginning: Bool
    let canSkipPrevious: Bool
    let canPlay: Bool
    let canSkipNext: Bool

    static func make(items: [BGMItem], currentItem: BGMItem?) -> BGMControlsState {
        let hasCurrent = currentItem != nil
        let hasLibrary = !items.isEmpty
        let sameCategoryCount: Int
        if let currentItem {
            sameCategoryCount = items.filter { $0.category == currentItem.category }.count
        } else {
            sameCategoryCount = 0
        }

        return BGMControlsState(
            canSeekToBeginning: hasCurrent,
            canSkipPrevious: hasCurrent && sameCategoryCount > 1,
            canPlay: hasCurrent || hasLibrary,
            canSkipNext: hasCurrent && sameCategoryCount > 1
        )
    }
}
