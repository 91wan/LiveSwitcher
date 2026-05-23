import Foundation

struct BGMCategorySelectionState: Equatable {
    var selectedCategory: BGMCategory
    private(set) var didManuallySelectCategory: Bool

    init(selectedCategory: BGMCategory, didManuallySelectCategory: Bool = false) {
        self.selectedCategory = selectedCategory
        self.didManuallySelectCategory = didManuallySelectCategory
    }

    mutating func selectCategory(_ category: BGMCategory) {
        selectedCategory = category
        didManuallySelectCategory = true
    }

    mutating func syncWithCurrentItem(_ currentItem: BGMItem?, allowsAutoSync: Bool) {
        guard allowsAutoSync, !didManuallySelectCategory, let currentItem else { return }
        selectedCategory = currentItem.category
    }
}
