import Foundation

enum BGMDefaultSelectionPolicy {
    static func defaultItem(
        items: [BGMItem],
        currentItem: BGMItem?,
        selectedCategory: BGMCategory
    ) -> BGMItem? {
        if let currentItem,
           items.contains(where: { $0.id == currentItem.id }) {
            return currentItem
        }
        return items.first { $0.category == selectedCategory }
    }
}
