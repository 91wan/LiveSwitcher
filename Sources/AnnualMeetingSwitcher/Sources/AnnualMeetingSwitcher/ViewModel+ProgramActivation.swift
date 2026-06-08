import AppKit

@MainActor
extension SwitcherViewModel {
    func switchToProgram(_ item: ProgramItem) {
        guard programSourceIsAvailable(item) else { return }
        guard let plan = ProgramActivationPlanner.plan(
            item: item,
            currentItem: currentProgramItem,
            queuedItems: programItems,
            isValidDeckDocument: { [weak self] url, kind in
                self?.isLikelyValidDeckDocument(url: url, sourceKind: kind) ?? false
            }
        ) else {
            return
        }

        executeProgramActivationPlan(plan)
    }

    func switchToProgramAfterReadinessConfirmation(_ item: ProgramItem) {
        let readiness = PresentationReadinessProbe.probe(item: item)
        guard readiness.severity == .blocked else {
            switchToProgram(item)
            return
        }

        let alert = NSAlert()
        alert.messageText = "Presentation is not ready"
        alert.informativeText = "\(readiness.operatorMessage)\n\nContinue anyway?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        switchToProgram(item)
    }

    func switchToProgram(at index: Int) {
        guard index >= 0 && index < programItems.count else { return }
        switchToProgram(programItems[index])
    }

    func confirmAgendaAutoAdvance(_ prompt: AgendaAutoAdvancePrompt) {
        agendaAutoAdvancePromptedItemIDs.insert(prompt.itemID)
        guard let item = programItems.first(where: { $0.id == prompt.itemID }) else { return }
        switchToProgramAfterReadinessConfirmation(item)
    }

    private func executeProgramActivationPlan(_ plan: ProgramActivationPlan) {
        if case .invalidDeck(let url) = plan.sideEffect {
            actionHandlers.invalidDeck(url)
            return
        }

        if plan.shouldStopCurrentDeckPresentation {
            actionHandlers.deckStop()
        }

        dispatchRuntimeProgramSelection(plan.runtimeSelection)
        setCurrentProgramFromOperatorSelection(plan.item)

        if plan.shouldClearHTML {
            currentHTMLURL = nil
        }

        switch plan.sideEffect {
        case .none:
            needsMutedMediaStartupAfterClearedProgram = false
        case .presentKeynote(let url):
            actionHandlers.keynotePresentation(url)
        case .openPPTX(let url):
            actionHandlers.pptxOpen(url)
        case .openHTML(let url):
            openHTMLInOutputWindow(url: url)
        case .presentActiveDeck:
            actionHandlers.activeDeckPresentation()
        case .invalidDeck:
            break
        }
    }

    private func setCurrentProgramFromOperatorSelection(_ item: ProgramItem?) {
        suppressCurrentProgramFacadeDispatch = true
        defer { suppressCurrentProgramFacadeDispatch = false }
        currentProgramItem = item
    }

    private func dispatchRuntimeProgramSelection(_ selection: ProgramActivationPlan.RuntimeSelection) {
        switch selection {
        case .queued(let id):
            dispatchRuntimeFacadeAction(.operatorSelectedProgram(id))
        case .detached(let item):
            dispatchRuntimeFacadeAction(.operatorSelectedDetachedProgram(item))
        }
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
