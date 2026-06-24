import Foundation

struct LiveBGMChooserModel: Equatable {
    struct Row: Identifiable, Equatable {
        let id: UUID
        let item: BGMItem
        let title: String
        let categoryTitle: String
        let isCurrent: Bool
        let stateText: String
        let systemImage: String
        let accessibilityLabel: String
    }

    let rows: [Row]
    let totalCount: Int
    let filteredCount: Int
    let emptyTitle: String
    let emptyMessage: String

    static func make(
        items: [BGMItem],
        currentItem: BGMItem?,
        phase: BGMPlaybackPhase,
        selectedCategory: BGMCategory?,
        searchText: String
    ) -> LiveBGMChooserModel {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredItems = items.filter { item in
            let categoryMatches = selectedCategory == nil || item.category == selectedCategory
            let searchMatches = trimmedSearch.isEmpty || item.title.localizedStandardContains(trimmedSearch)
            return categoryMatches && searchMatches
        }

        let rows = filteredItems.map { item in
            let isCurrent = item.id == currentItem?.id
            let state = rowState(isCurrent: isCurrent, phase: phase)
            return Row(
                id: item.id,
                item: item,
                title: item.title,
                categoryTitle: item.category.rawValue,
                isCurrent: isCurrent,
                stateText: state.text,
                systemImage: state.systemImage,
                accessibilityLabel: "\(item.title)，\(item.category.rawValue)，\(isCurrent ? "当前 BGM" : "BGM 曲目")，\(state.text)"
            )
        }

        let emptyCopy = emptyStateCopy(items: items)
        return LiveBGMChooserModel(
            rows: rows,
            totalCount: items.count,
            filteredCount: filteredItems.count,
            emptyTitle: emptyCopy.title,
            emptyMessage: emptyCopy.message
        )
    }

    private static func rowState(isCurrent: Bool, phase: BGMPlaybackPhase) -> (text: String, systemImage: String) {
        guard isCurrent else {
            return ("可播放", "music.note")
        }

        switch phase {
        case .playing:
            return ("播放中", "pause.fill")
        case .paused:
            return ("已暂停", "play.fill")
        case .idle, .selected:
            return ("已选", "checkmark")
        }
    }

    private static func emptyStateCopy(items: [BGMItem]) -> (title: String, message: String) {
        if items.isEmpty {
            return ("曲库为空", "到准备页面添加 BGM 后，可在现场选择已有曲目。")
        }
        return ("没有匹配曲目", "换一个关键词或分类。")
    }
}
