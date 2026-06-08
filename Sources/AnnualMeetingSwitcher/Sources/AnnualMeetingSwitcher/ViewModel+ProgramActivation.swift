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
        for effect in plan.preSelectionEffects {
            switch effect {
            case .stopDeck:
                programActivationSideEffects.stopDeck()
            case .presentInvalidDeckAlert(let url):
                programActivationSideEffects.presentInvalidDeckAlert(url)
                return
            }
        }

        guard let runtimeSelection = plan.runtimeSelection else { return }

        dispatchRuntimeProgramSelection(runtimeSelection)
        syncCurrentProgramFacadeFromRuntime()

        for effect in plan.postSelectionEffects {
            executePostSelectionProgramActivationEffect(effect)
        }
    }

    private func executePostSelectionProgramActivationEffect(
        _ effect: ProgramActivationPlan.PostSelectionEffect
    ) {
        switch effect {
        case .clearHTML:
            currentHTMLURL = nil
        case .resetMutedMediaStartupFlag:
            needsMutedMediaStartupAfterClearedProgram = false
        case .presentKeynote(let url):
            programActivationSideEffects.presentKeynote(url)
        case .openPPTX(let url):
            programActivationSideEffects.openPPTX(url)
        case .openHTML(let url):
            openHTMLInOutputWindow(url: url)
        case .presentActiveDeck:
            programActivationSideEffects.presentActiveDeck()
        }
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
