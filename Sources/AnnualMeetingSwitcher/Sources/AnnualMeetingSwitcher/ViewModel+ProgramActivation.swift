import AppKit

@MainActor
extension SwitcherViewModel {
    func switchToProgram(_ item: ProgramItem) {
        let activationItem = runtimeBackedProgramItemForActivationPlanning(item)
        guard programSourceIsAvailable(activationItem) else { return }
        guard let plan = ProgramActivationPlanner.plan(
            item: activationItem,
            currentItem: runtimeBackedCurrentProgramForActivationPlanning,
            queuedItems: runtimeBackedProgramItemsForActivationPlanning,
            isValidDeckDocument: { [weak self] url, kind in
                self?.isLikelyValidDeckDocument(url: url, sourceKind: kind) ?? false
            }
        ) else {
            return
        }

        dispatchRuntimeFacadeAction(.operatorRequestedProgramActivation(id: UUID(), plan: plan))
    }

    func switchToProgramAfterReadinessConfirmation(_ item: ProgramItem) {
        let activationItem = runtimeBackedProgramItemForActivationPlanning(item)
        let readiness = PresentationReadinessProbe.probe(item: activationItem)
        guard readiness.severity == .blocked else {
            switchToProgram(activationItem)
            return
        }

        let alert = NSAlert()
        alert.messageText = "Presentation is not ready"
        alert.informativeText = "\(readiness.operatorMessage)\n\nContinue anyway?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        switchToProgram(activationItem)
    }

    func switchToProgram(at index: Int) {
        let items = runtimeBackedProgramItemsForActivationPlanning
        guard index >= 0 && index < items.count else { return }
        switchToProgram(items[index])
    }

    func programShortcutTargetIndex(forKeyCode keyCode: UInt16) -> Int? {
        GlobalShortcutPolicy.programShortcutTargetIndex(
            for: keyCode,
            in: runtimeBackedProgramItemsForActivationPlanning
        )
    }

    func confirmAgendaAutoAdvance(_ prompt: AgendaAutoAdvancePrompt) {
        agendaAutoAdvancePromptedItemIDs.insert(prompt.itemID)
        guard let item = runtimeBackedProgramItemsForActivationPlanning.first(where: { $0.id == prompt.itemID }) else { return }
        switchToProgramAfterReadinessConfirmation(item)
    }

    private var runtimeBackedCurrentProgramForActivationPlanning: ProgramItem? {
        runtime.bridgeMode.owns(.programSelection)
            ? runtime.state.program.effectiveCurrentItem
            : currentProgramItem
    }

    private var runtimeBackedProgramItemsForActivationPlanning: [ProgramItem] {
        runtime.bridgeMode.owns(.programQueue)
            ? runtime.state.program.items
            : programItems
    }

    private func runtimeBackedProgramItemForActivationPlanning(_ item: ProgramItem) -> ProgramItem {
        guard runtime.bridgeMode.owns(.programQueue),
              let runtimeItem = runtime.state.program.items.first(where: { $0.id == item.id })
        else {
            return item
        }
        return runtimeItem
    }

    private func programSourceIsAvailable(_ item: ProgramItem) -> Bool {
        let result = ProgramSourceAvailabilityPolicy.availability(
            for: item,
            fileExists: { FileManager.default.fileExists(atPath: $0) }
        )
        guard let reason = result.unavailableReason else { return true }
        handleUnavailableProgramSource(item, kind: result.kind, reason: reason)
        return false
    }

    private func handleUnavailableProgramSource(
        _ item: ProgramItem,
        kind: ProgramSourceKind,
        reason: ProgramSourceUnavailableReason
    ) {
        recordSupportEvent(
            kind: .programItemFileMissing,
            detail: "sourceKind=\(ProgramSourceAvailabilityPolicy.supportLabel(for: kind)),reason=\(reason.rawValue)"
        )
        showAutomationRuntimeNotice(action: "program.source.missing")
    }
}
