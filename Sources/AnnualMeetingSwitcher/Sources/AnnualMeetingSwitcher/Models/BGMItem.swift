import Foundation

struct BGMItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var url: URL
    var category: BGMCategory

    init(id: UUID = UUID(), title: String, url: URL, category: BGMCategory = .warmUp) {
        self.id = id
        self.title = title
        self.url = url
        self.category = category
    }
}
