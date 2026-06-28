enum ProgramRuntimeActionDispatcher {
    static func dispatch(
        action: LiveRuntimeAction,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        environment: LiveRuntimeEnvironment
    ) -> Bool {
        let bridgeMode = environment.bridgeMode

        switch action {
        case .operatorSelectedProgram(let id):
            guard LiveRuntimeReducer.isRuntimeOwned(.programSelection, in: bridgeMode) else { return true }
            guard let item = ProgramSelectionRuntimeReducer.selectedProgramItem(id, in: state) else { return true }
            ProgramSelectionRuntimeReducer.selectProgram(
                item,
                state: &state,
                effects: &effects,
                now: environment.now,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorSelectedDetachedProgram(let item):
            guard LiveRuntimeReducer.isRuntimeOwned(.programSelection, in: bridgeMode) else { return true }
            ProgramSelectionRuntimeReducer.selectProgram(
                item,
                state: &state,
                effects: &effects,
                now: environment.now,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorClearedCurrentProgram:
            guard LiveRuntimeReducer.isRuntimeOwned(.programSelection, in: bridgeMode) else { return true }
            ProgramSelectionRuntimeReducer.clearCurrentProgram(
                state: &state,
                effects: &effects,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )

        case .operatorRequestedProgramActivation(let id, let plan):
            guard LiveRuntimeReducer.isRuntimeOwned(.programActivation, in: bridgeMode) else { return true }
            ProgramActivationRuntimeReducer.request(
                id: id,
                plan: plan,
                state: &state,
                effects: &effects
            )

        case .programActivationCompleted(let id):
            guard LiveRuntimeReducer.isRuntimeOwned(.programActivation, in: bridgeMode) else { return true }
            ProgramActivationRuntimeReducer.complete(id: id, state: &state)

        case .operatorAddedProgramItems(let items):
            guard LiveRuntimeReducer.isRuntimeOwned(.programQueue, in: bridgeMode) else { return true }
            ProgramQueueRuntimeReducer.addProgramItems(items, state: &state)

        case .operatorRemovedProgramItem(let id):
            guard LiveRuntimeReducer.isRuntimeOwned(.programQueue, in: bridgeMode) else { return true }
            ProgramQueueRuntimeReducer.removeProgramItem(id: id, state: &state)

        case .operatorMovedProgramItems(let fromOffsets, let toOffset):
            guard LiveRuntimeReducer.isRuntimeOwned(.programQueue, in: bridgeMode) else { return true }
            ProgramQueueRuntimeReducer.moveProgramItems(fromOffsets: fromOffsets, toOffset: toOffset, state: &state)

        case .operatorUpdatedProgramItemSchedule(let id, let scheduledStartAt, let scheduledDuration):
            guard LiveRuntimeReducer.isRuntimeOwned(.programQueue, in: bridgeMode) else { return true }
            ProgramQueueRuntimeReducer.updateProgramItemSchedule(
                id: id,
                scheduledStartAt: scheduledStartAt,
                scheduledDuration: scheduledDuration,
                state: &state
            )

        case .operatorAddedAgendaMarker(let input):
            guard LiveRuntimeReducer.isRuntimeOwned(.programQueue, in: bridgeMode) else { return true }
            ProgramQueueRuntimeReducer.addAgendaMarker(input: input, state: &state)

        case .operatorUpdatedAgendaMarker(let id, let input):
            guard LiveRuntimeReducer.isRuntimeOwned(.programQueue, in: bridgeMode) else { return true }
            ProgramQueueRuntimeReducer.updateAgendaMarker(id: id, input: input, state: &state)

        case .facadeLoadedProgramQueue(let items):
            guard LiveRuntimeReducer.isRuntimeOwned(.programQueue, in: bridgeMode) else { return true }
            ProgramQueueRuntimeReducer.loadProgramQueueFromFacade(items, state: &state)

        default:
            return false
        }

        return true
    }
}
