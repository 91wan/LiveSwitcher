import Foundation

@MainActor
extension SwitcherViewModel {
    func executeProgramActivationPlanFromRuntime(
        id: UUID,
        plan: ProgramActivationPlan,
        context: LiveRuntimeEffectExecutionContext
    ) {
        guard context.currentState().programActivation.activeRequestID == id else {
            return
        }

        defer {
            if context.currentState().programActivation.activeRequestID == id {
                context.dispatch(.programActivationCompleted(id: id))
            }
        }

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

        guard dispatchProgramActivationRuntimeSelectionAndConfirm(
            runtimeSelection,
            expectedItemID: plan.item.id,
            context: context
        ) else {
            return
        }

        for effect in plan.postSelectionEffects {
            executePostSelectionProgramActivationEffect(effect)
        }
    }

    private func dispatchProgramActivationRuntimeSelectionAndConfirm(
        _ selection: ProgramActivationPlan.RuntimeSelection,
        expectedItemID: UUID,
        context: LiveRuntimeEffectExecutionContext
    ) -> Bool {
        switch selection {
        case .queued(let id):
            context.dispatch(.operatorSelectedProgram(id))
        case .detached(let item):
            context.dispatch(.operatorSelectedDetachedProgram(item))
        }

        syncCurrentProgramFacadeFromRuntime()

        return context.currentState().program.effectiveCurrentItem?.id == expectedItemID
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
}
