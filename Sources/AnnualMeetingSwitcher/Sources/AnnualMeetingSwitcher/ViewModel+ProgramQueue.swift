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

    func addAgendaMarker(title: String = "Break") {
        dispatchRuntimeFacadeAction(.operatorAddedAgendaMarker(title: title))
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
        let removedItem = programItems.first { $0.id == id }
        let isCurrent = currentProgramItem?.id == id
        if isCurrent {
            needsMutedMediaStartupAfterClearedProgram = removedItem?.sourceKind == .media
            if removedItem?.supportsPresentationControl == true {
                actionHandlers.deckStop()
            }
            if removedItem?.sourceKind == .media {
                dispatchRuntimeFacadeAction(.operatorStoppedCurrentMedia)
            }
            currentHTMLURL = nil   // Bug2修复：删除HTML条目时清空大屏
        }
        dispatchRuntimeFacadeAction(.operatorRemovedProgramItem(id))
        if isCurrent && !runtime.bridgeMode.owns(.programSelection) {
            applyCurrentProgramProjectionFromRuntime(nil, switchedAt: nil)
        }
        saveData()
    }

    func moveProgramItems(from source: IndexSet, to destination: Int) {
        dispatchRuntimeFacadeAction(.operatorMovedProgramItems(
            fromOffsets: Array(source),
            toOffset: destination
        ))
        saveData()
    }

    func agendaAutoAdvancePrompt(now: Date = Date()) -> AgendaAutoAdvancePrompt? {
        AgendaAutoAdvanceModel.prompt(
            isEnabled: autoAdvanceAtScheduledTime,
            programItems: programItems,
            currentProgramItem: currentProgramItem,
            now: now,
            promptedItemIDs: agendaAutoAdvancePromptedItemIDs
        )
    }

    func dismissAgendaAutoAdvancePrompt(_ prompt: AgendaAutoAdvancePrompt) {
        agendaAutoAdvancePromptedItemIDs.insert(prompt.itemID)
    }
}
