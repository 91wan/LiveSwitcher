import Foundation

enum ProgramActivationRuntimeReducer {
    static func request(
        id: UUID,
        plan: ProgramActivationPlan,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        state.programActivation.startRequest(id: id)
        effects.append(.executeProgramActivation(id: id, plan: plan))
    }

    static func complete(
        id: UUID,
        state: inout LiveRuntimeState
    ) {
        state.programActivation.completeRequest(id: id)
    }
}
