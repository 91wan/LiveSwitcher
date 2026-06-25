import Foundation

@MainActor
extension SwitcherViewModel {
    // MARK: - 节目操作

    func addProgramItem(_ item: ProgramItem) {
        addProgramItems([item])
    }

    func addProgramItems(_ items: [ProgramItem]) {
        guard !items.isEmpty else { return }
        dispatchRuntimeFacadeAction(.operatorAddedProgramItems(items))
        saveData()
    }

    func addAgendaMarker(_ input: AgendaMarkerInput) {
        dispatchRuntimeFacadeAction(.operatorAddedAgendaMarker(input))
        saveData()
    }

    func updateAgendaMarker(id: UUID, input: AgendaMarkerInput) {
        dispatchRuntimeFacadeAction(.operatorUpdatedAgendaMarker(id: id, input: input))
        agendaAutoAdvancePromptedItemIDs.remove(id)
        saveData()
    }

    func updateProgramItemSchedule(
        id: UUID,
        scheduledStartAt: Date?,
        scheduledDuration: TimeInterval?
    ) {
        dispatchRuntimeFacadeAction(.operatorUpdatedProgramItemSchedule(
            id: id,
            scheduledStartAt: scheduledStartAt,
            scheduledDuration: scheduledDuration
        ))
        agendaAutoAdvancePromptedItemIDs.remove(id)
        saveData()
    }

    func removeProgramItem(withID id: UUID) {
        let removedItem = runtimeBackedProgramItemForProgramQueueViewModel(id: id)
        let currentProgram = runtimeBackedCurrentProgramForProgramQueueViewModel
        let isCurrent = currentProgram?.id == id && removedItem != nil
        if isCurrent {
            needsMutedMediaStartupAfterClearedProgram = removedItem?.sourceKind == .media
            if removedItem?.supportsPresentationControl == true {
                programActivationSideEffects.stopDeck()
            }
            if removedItem?.sourceKind == .media {
                dispatchRuntimeFacadeAction(.operatorStoppedCurrentMedia)
            }
            currentHTMLURL = nil   // Bug2修复：删除HTML条目时清空大屏
        }
        dispatchRuntimeFacadeAction(.operatorRemovedProgramItem(id))
        if isCurrent && !runtime.bridgeMode.owns(.programSelection) {
            clearCurrentProgramSelection(reason: .operatorCleared)
        }
        saveData()
    }

    func removeProgramItems(at indexSet: IndexSet) {
        let currentItems = runtimeBackedProgramItemsForProgramQueueViewModel
        let ids = indexSet.compactMap { index in
            currentItems.indices.contains(index) ? currentItems[index].id : nil
        }
        ids.forEach { removeProgramItem(withID: $0) }
    }

    func moveProgramItems(from source: IndexSet, to destination: Int) {
        dispatchRuntimeFacadeAction(.operatorMovedProgramItems(
            fromOffsets: Array(source),
            toOffset: destination
        ))
        saveData()
    }

    @discardableResult
    func moveProgramItem(
        draggedID: UUID,
        targetID: UUID,
        placement: ProgramQueueDropPlacement
    ) -> Bool {
        let itemIDs = runtimeBackedProgramItemsForProgramQueueViewModel.map(\.id)
        let plan = ProgramQueueDropPlan(
            draggedID: draggedID,
            targetID: targetID,
            placement: placement
        )
        guard let move = plan.resolvedMove(in: itemIDs) else { return false }
        moveProgramItems(from: move.fromOffsets, to: move.toOffset)
        return true
    }

    func agendaAutoAdvancePrompt(now: Date = Date()) -> AgendaAutoAdvancePrompt? {
        AgendaAutoAdvanceModel.prompt(
            isEnabled: runtimeBackedAutoAdvanceAtScheduledTimeForProgramQueueViewModel,
            programItems: runtimeBackedProgramItemsForProgramQueueViewModel,
            currentProgramItem: runtimeBackedCurrentProgramForProgramQueueViewModel,
            now: now,
            promptedItemIDs: agendaAutoAdvancePromptedItemIDs
        )
    }

    func dismissAgendaAutoAdvancePrompt(_ prompt: AgendaAutoAdvancePrompt) {
        agendaAutoAdvancePromptedItemIDs.insert(prompt.itemID)
    }

    private var runtimeBackedProgramItemsForProgramQueueViewModel: [ProgramItem] {
        runtime.bridgeMode.owns(.programQueue)
            ? runtime.state.program.items
            : programItems
    }

    private var runtimeBackedCurrentProgramForProgramQueueViewModel: ProgramItem? {
        runtime.bridgeMode.owns(.programSelection)
            ? runtime.state.program.effectiveCurrentItem
            : currentProgramItem
    }

    private var runtimeBackedAutoAdvanceAtScheduledTimeForProgramQueueViewModel: Bool {
        runtime.bridgeMode.owns(.persistence)
            ? runtime.state.preferences.autoAdvanceAtScheduledTime
            : autoAdvanceAtScheduledTime
    }

    private func runtimeBackedProgramItemForProgramQueueViewModel(id: UUID) -> ProgramItem? {
        runtimeBackedProgramItemsForProgramQueueViewModel.first { $0.id == id }
    }
}
