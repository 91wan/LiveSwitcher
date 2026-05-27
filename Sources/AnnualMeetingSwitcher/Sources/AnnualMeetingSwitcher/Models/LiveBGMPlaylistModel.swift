import Foundation

struct LiveBGMPlaylistModel: Equatable {
    struct Row: Identifiable, Equatable {
        let id: UUID
        let item: BGMItem
        let title: String
        let isCurrent: Bool
        let systemImage: String
        let accessibilityLabel: String
    }

    let displayCategory: BGMCategory
    let rows: [Row]
    let visibleRowLimit: Int
    let remainingCount: Int
    let categoryButtonTitle: String
    let emptyMessage: String

    var remainingCountText: String? {
        remainingCount > 0 ? "+\(remainingCount) 首" : nil
    }

    static func make(
        items: [BGMItem],
        currentItem: BGMItem?,
        selectedCategory: BGMCategory,
        isPlaying: Bool,
        visibleRowLimit: Int = 5
    ) -> LiveBGMPlaylistModel {
        let displayCategory: BGMCategory
        if items.isEmpty || items.contains(where: { $0.category == selectedCategory }) {
            displayCategory = selectedCategory
        } else {
            displayCategory = BGMCategory.allCases.first { category in
                items.contains { $0.category == category }
            } ?? selectedCategory
        }
        let categoryItems = items.filter { $0.category == displayCategory }
        let cappedLimit = max(visibleRowLimit, 1)
        var visibleItems = Array(categoryItems.prefix(cappedLimit))
        if let currentItem,
           currentItem.category == displayCategory,
           !visibleItems.contains(where: { $0.id == currentItem.id }) {
            if visibleItems.count >= cappedLimit {
                visibleItems.removeLast()
            }
            visibleItems.insert(currentItem, at: 0)
        }
        let rows = visibleItems.map { item in
            let isCurrent = item.id == currentItem?.id
            let systemImage: String
            let stateText: String
            if isCurrent && isPlaying {
                systemImage = "pause.fill"
                stateText = "播放中"
            } else if isCurrent {
                systemImage = "checkmark"
                stateText = "已选"
            } else {
                systemImage = "music.note"
                stateText = "可播放"
            }

            return Row(
                id: item.id,
                item: item,
                title: item.title,
                isCurrent: isCurrent,
                systemImage: systemImage,
                accessibilityLabel: "\(item.title)，\(isCurrent ? "当前 BGM" : "BGM 曲目")，\(stateText)"
            )
        }

        return LiveBGMPlaylistModel(
            displayCategory: displayCategory,
            rows: rows,
            visibleRowLimit: cappedLimit,
            remainingCount: max(categoryItems.count - cappedLimit, 0),
            categoryButtonTitle: "切换分类",
            emptyMessage: "\(displayCategory.rawValue) 没有曲目"
        )
    }
}
