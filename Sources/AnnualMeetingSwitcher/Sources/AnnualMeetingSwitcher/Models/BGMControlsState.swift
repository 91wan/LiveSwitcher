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
            // BGM playback is safe active audio, not critical projection state.
            displayStatus = ("播放中", .ready)
        } else if !hasLibraryItems {
            displayStatus = ("空", .warn)
        } else if currentItem != nil {
            displayStatus = ("已选", .idle)
        } else {
            displayStatus = ("待选", .idle)
        }
        let skipDisabledReason: String?
        if canSkip {
            skipDisabledReason = nil
        } else if !hasLibraryItems {
            skipDisabledReason = "请先添加 BGM。"
        } else if currentItem == nil {
            skipDisabledReason = "请先选择或播放一首 BGM。"
        } else {
            skipDisabledReason = "当前分类至少需要两首曲目。"
        }

        return BGMControlsState(
            canSeekToBeginning: currentItem != nil,
            canSkipPrevious: canSkip,
            canPlay: currentItem != nil || hasLibraryItems,
            canSkipNext: canSkip,
            displayStatusText: displayStatus.text,
            displayStatusKind: displayStatus.kind,
            playDisabledReason: hasLibraryItems ? nil : "请先添加 BGM。",
            skipDisabledReason: skipDisabledReason,
            seekDisabledReason: currentItem == nil ? "请先选择或播放一首 BGM。" : nil
        )
    }
}
