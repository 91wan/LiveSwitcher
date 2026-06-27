import Foundation

struct ProgramRuntimeState: Equatable {
    var items: [ProgramItem] = []
    var currentID: UUID?
    var currentDetachedItem: ProgramItem?
    var currentSwitchedAt: Date?

    var currentItem: ProgramItem? {
        guard let currentID else { return nil }
        return items.first { $0.id == currentID }
    }

    var effectiveCurrentItem: ProgramItem? {
        currentItem ?? currentDetachedItem
    }
}
