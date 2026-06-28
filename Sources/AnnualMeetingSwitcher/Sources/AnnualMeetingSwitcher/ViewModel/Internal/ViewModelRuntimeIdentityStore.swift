import Foundation

struct ViewModelRuntimeIdentityStore {
    private(set) var activeMediaGeneration: Int?
    private(set) var activeMediaURL: URL?
    private(set) var activeBGMGeneration: Int?
    private(set) var activeBGMItemID: UUID?
    private(set) var activeBGMURL: URL?
    private(set) var transientBGMItem: BGMItem?

    mutating func setActiveMedia(generation: Int, url: URL) {
        activeMediaGeneration = generation
        activeMediaURL = url
    }

    mutating func clearActiveMedia(ifGeneration generation: Int) {
        guard activeMediaGeneration == generation else { return }
        activeMediaGeneration = nil
        activeMediaURL = nil
    }

    func validatedMediaGeneration(
        runtimeGeneration: Int?,
        currentProgram: ProgramItem?,
        currentMediaURL: URL?
    ) -> Int? {
        guard let generation = activeMediaGeneration else { return nil }

        if let runtimeGeneration {
            guard generation == runtimeGeneration else { return nil }
        }

        guard let currentProgram,
              currentProgram.sourceKind == .media
        else { return nil }

        guard currentProgram.sourceURL == activeMediaURL else { return nil }
        guard currentMediaURL == activeMediaURL else { return nil }

        return generation
    }

    mutating func setActiveBGM(item: BGMItem, generation: Int) {
        activeBGMGeneration = generation
        activeBGMItemID = item.id
        activeBGMURL = item.url
    }

    mutating func clearActiveBGM() {
        activeBGMGeneration = nil
        activeBGMItemID = nil
        activeBGMURL = nil
    }

    func validatedBGMGeneration(runtimeGeneration: Int?, currentItem: BGMItem?) -> Int? {
        guard let generation = activeBGMGeneration else { return nil }

        if let runtimeGeneration {
            guard generation == runtimeGeneration else { return nil }
        }

        guard let currentItem else { return nil }
        guard currentItem.id == activeBGMItemID else { return nil }
        guard currentItem.url == activeBGMURL else { return nil }

        return generation
    }

    mutating func includeTransientBGMItem(_ item: BGMItem) {
        transientBGMItem = item
    }

    mutating func clearTransientBGMItemIfNeeded(_ item: BGMItem) {
        guard transientBGMItem?.id == item.id else { return }
        transientBGMItem = nil
    }

    func runtimeBGMItems(
        libraryItems: [BGMItem],
        runtimeCurrentItem: BGMItem?,
        facadeCurrentItem: BGMItem?
    ) -> [BGMItem] {
        var items = libraryItems
        appendIfMissing(runtimeCurrentItem, to: &items)
        appendIfMissing(facadeCurrentItem, to: &items)
        appendIfMissing(transientBGMItem, to: &items)
        return items
    }

    private func appendIfMissing(_ item: BGMItem?, to items: inout [BGMItem]) {
        guard let item,
              !items.contains(where: { $0.id == item.id })
        else { return }

        items.append(item)
    }
}
