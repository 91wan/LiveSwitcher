import Foundation

struct BGMCategorySelectionState: Equatable {
    var selectedCategory: BGMCategory
    private var lastCurrentItemID: UUID?
    private var manuallySelectedCurrentItemID: UUID?

    init(selectedCategory: BGMCategory) {
        self.selectedCategory = selectedCategory
    }

    mutating func selectCategory(_ category: BGMCategory) {
        selectedCategory = category
        manuallySelectedCurrentItemID = lastCurrentItemID
    }

    mutating func syncWithCurrentItem(_ currentItem: BGMItem?, allowsAutoSync: Bool) {
        guard allowsAutoSync, let currentItem else { return }

        if currentItem.id != lastCurrentItemID {
            selectedCategory = currentItem.category
            lastCurrentItemID = currentItem.id
            manuallySelectedCurrentItemID = nil
            return
        }

        guard manuallySelectedCurrentItemID != currentItem.id else { return }
        selectedCategory = currentItem.category
    }
}
