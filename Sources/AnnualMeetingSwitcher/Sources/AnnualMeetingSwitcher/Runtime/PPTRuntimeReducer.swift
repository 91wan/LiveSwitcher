import Foundation

enum PPTRuntimeReducer {
    static func toggleMode(
        source: PPTModeToggleSource,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        setMode(
            !(state.ppt.isRequested || state.ppt.isEventTapActive),
            source: source,
            state: &state,
            effects: &effects
        )
    }

    static func setMode(
        _ isEnabled: Bool,
        source: PPTModeToggleSource,
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect]
    ) {
        _ = source
        if isEnabled {
            guard !state.ppt.isRequested, !state.ppt.isEventTapActive else { return }
            state.ppt.isRequested = true
            state.ppt.isEventTapActive = false
            state.ppt.lastFailureReason = nil
            effects.append(.startPPTEventTap)
            return
        }

        guard state.ppt.isRequested || state.ppt.isEventTapActive else { return }
        state.ppt.isRequested = false
        state.ppt.isEventTapActive = false
        effects.append(.stopPPTEventTap(reason: .operatorDisabled))
    }

    static func eventTapStarted(state: inout LiveRuntimeState) {
        state.ppt.isRequested = true
        state.ppt.isEventTapActive = true
        state.ppt.lastFailureReason = nil
    }

    static func eventTapFailed(reason: String, state: inout LiveRuntimeState) {
        state.ppt.isRequested = false
        state.ppt.isEventTapActive = false
        state.ppt.lastFailureReason = reason
    }

    static func eventTapStopped(reason: PPTStopReason, state: inout LiveRuntimeState) {
        _ = reason
        state.ppt.isRequested = false
        state.ppt.isEventTapActive = false
    }
}
