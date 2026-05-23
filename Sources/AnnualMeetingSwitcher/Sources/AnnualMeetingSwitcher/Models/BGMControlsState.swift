import Foundation

struct BGMControlsState: Equatable {
    let canSeekToBeginning: Bool
    let canSkipPrevious: Bool
    let canPlay: Bool
    let canSkipNext: Bool
    let displayStatusText: String
    let displayStatusKind: StudioTheme.StatusKind
    let playDisabledReason: String?
    let skipDisabledReason: String?
    let seekDisabledReason: String?

    static func make(items: [BGMItem], currentItem: BGMItem?, isPlaying: Bool = false) -> BGMControlsState {
        let hasLibraryItems = !items.isEmpty
        let categoryItems: [BGMItem]
        if let currentItem {
            categoryItems = items.filter { $0.category == currentItem.category }
        } else {
            categoryItems = []
        }
        let canSkip = currentItem != nil && categoryItems.count >= 2
        let displayStatus: (text: String, kind: StudioTheme.StatusKind)
        if isPlaying {
            displayStatus = ("PLAYING", .ready)
        } else if !hasLibraryItems {
            displayStatus = ("EMPTY", .warn)
        } else if currentItem != nil {
            displayStatus = ("CUED", .idle)
        } else {
            displayStatus = ("SELECT", .idle)
        }

        return BGMControlsState(
            canSeekToBeginning: currentItem != nil,
            canSkipPrevious: canSkip,
            canPlay: currentItem != nil || hasLibraryItems,
            canSkipNext: canSkip,
            displayStatusText: displayStatus.text,
            displayStatusKind: displayStatus.kind,
            playDisabledReason: hasLibraryItems ? nil : "Add music before starting BGM.",
            skipDisabledReason: canSkip ? nil : "At least two tracks in the current category are required.",
            seekDisabledReason: currentItem == nil ? "Select or start a BGM track first." : nil
        )
    }
}
