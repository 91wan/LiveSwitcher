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
        remainingCount > 0 ? "+\(remainingCount) more" : nil
    }

    static func make(
        items: [BGMItem],
        currentItem: BGMItem?,
        selectedCategory: BGMCategory,
        isPlaying: Bool,
        visibleRowLimit: Int = 3
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
        let visibleItems = Array(categoryItems.prefix(visibleRowLimit))
        let rows = visibleItems.map { item in
            let isCurrent = item.id == currentItem?.id
            let systemImage: String
            let stateText: String
            if isCurrent && isPlaying {
                systemImage = "pause.fill"
                stateText = "playing"
            } else if isCurrent {
                systemImage = "checkmark"
                stateText = "cued"
            } else {
                systemImage = "music.note"
                stateText = "available"
            }

            return Row(
                id: item.id,
                item: item,
                title: item.title,
                isCurrent: isCurrent,
                systemImage: systemImage,
                accessibilityLabel: "\(item.title), \(isCurrent ? "current BGM" : "BGM track"), \(stateText)"
            )
        }

        return LiveBGMPlaylistModel(
            displayCategory: displayCategory,
            rows: rows,
            visibleRowLimit: visibleRowLimit,
            remainingCount: max(categoryItems.count - visibleRowLimit, 0),
            categoryButtonTitle: "切换分类",
            emptyMessage: "No tracks in \(displayCategory.rawValue)"
        )
    }
}
