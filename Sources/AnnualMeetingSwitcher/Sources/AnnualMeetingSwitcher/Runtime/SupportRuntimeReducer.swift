import Foundation

enum SupportRuntimeReducer {
    static func record(
        event: LiveSupportEvent,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        if let accepted = state.support.record(event: event) {
            effects.append(.recordSupportEvent(accepted))
        }
    }

    static func record(
        kind: LiveSupportEventKind,
        detail: String,
        at date: Date,
        state: inout LiveRuntimeState
    ) {
        state.support.record(kind: kind, detail: detail, at: date)
    }
}
