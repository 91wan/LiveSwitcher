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

        let sideEffect: ProgramActivationPlan.SideEffect
        let shouldClearHTML: Bool
        switch sourceKind {
        case .agendaMarker, .unsupported:
            return nil
        case .media:
            sideEffect = .none
            shouldClearHTML = true
        case .keynote:
            guard let url = item.sourceURL else { return nil }
            sideEffect = isValidDeckDocument(url, .keynote) ? .presentKeynote(url) : .invalidDeck(url)
            shouldClearHTML = true
        case .pptx:
            guard let url = item.sourceURL else { return nil }
            sideEffect = isValidDeckDocument(url, .pptx) ? .openPPTX(url) : .invalidDeck(url)
            shouldClearHTML = true
        case .html:
            guard let url = item.sourceURL else { return nil }
            sideEffect = .openHTML(url)
            shouldClearHTML = false
        case .activeDeck:
            sideEffect = .presentActiveDeck
            shouldClearHTML = true
        }

        let runtimeSelection: ProgramActivationPlan.RuntimeSelection = queuedItems.contains(where: { $0.id == item.id })
            ? .queued(item.id)
            : .detached(item)
        let shouldStopCurrentDeckPresentation = currentItem.map {
            $0.id != item.id && $0.supportsPresentationControl
        } ?? false

        return ProgramActivationPlan(
            item: item,
            runtimeSelection: runtimeSelection,
            shouldStopCurrentDeckPresentation: shouldStopCurrentDeckPresentation,
            shouldClearHTML: shouldClearHTML,
            sideEffect: sideEffect
        )
    }
}
