import Foundation

enum ProgramQueueRuntimeReducer {
    static func addProgramItems(
        _ items: [ProgramItem],
        state: inout LiveRuntimeState
    ) {
        state.program.appendProgramItems(items)
    }

    static func removeProgramItem(
        id: UUID,
        state: inout LiveRuntimeState
    ) {
        state.program.removeProgramItem(id: id)
    }

    static func moveProgramItems(
        fromOffsets: [Int],
        toOffset: Int,
        state: inout LiveRuntimeState
    ) {
        state.program.moveProgramItems(fromOffsets: fromOffsets, toOffset: toOffset)
    }

    static func updateProgramItemSchedule(
        id: UUID,
        scheduledStartAt: Date?,
        scheduledDuration: TimeInterval?,
        state: inout LiveRuntimeState
    ) {
        state.program.updateProgramItemSchedule(
            id: id,
            scheduledStartAt: scheduledStartAt,
            scheduledDuration: scheduledDuration
        )
    }

    static func addAgendaMarker(
        input: AgendaMarkerInput,
        state: inout LiveRuntimeState
    ) {
        state.program.appendAgendaMarker(input: input)
    }

    static func updateAgendaMarker(
        id: UUID,
        input: AgendaMarkerInput,
        state: inout LiveRuntimeState
    ) {
        state.program.updateAgendaMarker(id: id, input: input)
    }

    static func loadProgramQueueFromFacade(
        _ items: [ProgramItem],
        state: inout LiveRuntimeState
    ) {
        state.program.replaceProgramQueueFromFacade(items)
    }
}
