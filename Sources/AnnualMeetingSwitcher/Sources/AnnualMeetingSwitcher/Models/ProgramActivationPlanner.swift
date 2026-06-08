import Foundation

enum ProgramActivationPlanner {
    static func plan(
        item: ProgramItem,
        currentItem: ProgramItem?,
        queuedItems: [ProgramItem],
        isValidDeckDocument: (URL, ProgramSourceKind) -> Bool
    ) -> ProgramActivationPlan? {
        let sourceKind = item.sourceKind
        guard sourceKind.isActivatableProgram else { return nil }

        let runtimeSelection: ProgramActivationPlan.RuntimeSelection?
        let preSelectionEffects: [ProgramActivationPlan.PreSelectionEffect]
        let postSelectionEffects: [ProgramActivationPlan.PostSelectionEffect]
        switch sourceKind {
        case .agendaMarker, .unsupported:
            return nil
        case .media:
            runtimeSelection = self.runtimeSelection(for: item, queuedItems: queuedItems)
            preSelectionEffects = self.preSelectionEffects(currentItem: currentItem, nextItem: item)
            postSelectionEffects = [.clearHTML, .resetMutedMediaStartupFlag]
        case .keynote:
            guard let url = item.sourceURL else { return nil }
            if isValidDeckDocument(url, .keynote) {
                runtimeSelection = self.runtimeSelection(for: item, queuedItems: queuedItems)
                preSelectionEffects = self.preSelectionEffects(currentItem: currentItem, nextItem: item)
                postSelectionEffects = [.clearHTML, .presentKeynote(url)]
            } else {
                runtimeSelection = nil
                preSelectionEffects = [.presentInvalidDeckAlert(url)]
                postSelectionEffects = []
            }
        case .pptx:
            guard let url = item.sourceURL else { return nil }
            if isValidDeckDocument(url, .pptx) {
                runtimeSelection = self.runtimeSelection(for: item, queuedItems: queuedItems)
                preSelectionEffects = self.preSelectionEffects(currentItem: currentItem, nextItem: item)
                postSelectionEffects = [.clearHTML, .openPPTX(url)]
            } else {
                runtimeSelection = nil
                preSelectionEffects = [.presentInvalidDeckAlert(url)]
                postSelectionEffects = []
            }
        case .html:
            guard let url = item.sourceURL else { return nil }
            runtimeSelection = self.runtimeSelection(for: item, queuedItems: queuedItems)
            preSelectionEffects = self.preSelectionEffects(currentItem: currentItem, nextItem: item)
            postSelectionEffects = [.openHTML(url)]
        case .activeDeck:
            runtimeSelection = self.runtimeSelection(for: item, queuedItems: queuedItems)
            preSelectionEffects = self.preSelectionEffects(currentItem: currentItem, nextItem: item)
            postSelectionEffects = [.clearHTML, .presentActiveDeck]
        }

        return ProgramActivationPlan(
            item: item,
            runtimeSelection: runtimeSelection,
            preSelectionEffects: preSelectionEffects,
            postSelectionEffects: postSelectionEffects
        )
    }

    private static func runtimeSelection(
        for item: ProgramItem,
        queuedItems: [ProgramItem]
    ) -> ProgramActivationPlan.RuntimeSelection {
        queuedItems.contains(where: { $0.id == item.id })
            ? .queued(item.id)
            : .detached(item)
    }

    private static func preSelectionEffects(
        currentItem: ProgramItem?,
        nextItem: ProgramItem
    ) -> [ProgramActivationPlan.PreSelectionEffect] {
        guard let currentItem,
              currentItem.id != nextItem.id,
              currentItem.supportsPresentationControl
        else { return [] }
        return [.stopDeck]
    }
}
