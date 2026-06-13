import Foundation

@MainActor
extension SwitcherViewModel {
    func executeProgramActivationPlanFromRuntime(
        id: UUID,
        plan: ProgramActivationPlan,
        context: LiveRuntimeEffectExecutionContext
    ) {
        defer {
            context.dispatch(.programActivationCompleted(id: id))
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

        dispatchProgramActivationRuntimeSelection(runtimeSelection, context: context)
        syncCurrentProgramFacadeFromRuntime()

        for effect in plan.postSelectionEffects {
            executePostSelectionProgramActivationEffect(effect)
        }
    }

    private func dispatchProgramActivationRuntimeSelection(
        _ selection: ProgramActivationPlan.RuntimeSelection,
        context: LiveRuntimeEffectExecutionContext
    ) {
        switch selection {
        case .queued(let id):
            context.dispatch(.operatorSelectedProgram(id))
        case .detached(let item):
            context.dispatch(.operatorSelectedDetachedProgram(item))
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
}
