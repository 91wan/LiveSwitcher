import Foundation

struct LiveBGMQuickPickerModel: Equatable {
    struct Section: Identifiable, Equatable {
        let category: BGMCategory
        let tracks: [BGMItem]

        var id: BGMCategory { category }
        var title: String { category.rawValue }
        var isEmpty: Bool { tracks.isEmpty }
    }

    let currentTitle: String
    let sections: [Section]

    var isLibraryEmpty: Bool {
        sections.allSatisfy(\.isEmpty)
    }

    var nonEmptySections: [Section] {
        sections.filter { !$0.isEmpty }
    }

    func section(for category: BGMCategory) -> Section? {
        sections.first { $0.category == category }
    }

    static func make(items: [BGMItem], currentItem: BGMItem?) -> LiveBGMQuickPickerModel {
        LiveBGMQuickPickerModel(
            currentTitle: currentItem?.title ?? "未选择 BGM",
            sections: BGMCategory.allCases.map { category in
                Section(
                    category: category,
                    tracks: items.filter { $0.category == category }
                )
            }
        )
    }
}
