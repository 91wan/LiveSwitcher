import Foundation

enum ProjectionRuntimeReducer {
    static func toggleProjection(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        canWriteSupport: Bool,
        now: Date
    ) {
        if state.projection.isBroadcasting {
            state.projection.isBroadcasting = false
            state.projection.safetyNotice = nil
            effects.append(.stopProjection)
            if canWriteSupport {
                state.support.record(kind: .projectionStopped, detail: "source=runtime", at: now)
            }
        } else if state.projection.hasExternalDisplay {
            state.projection.isBroadcasting = true
            state.projection.safetyNotice = nil
            effects.append(.startProjection)
            if canWriteSupport {
                state.support.record(kind: .projectionStarted, detail: "source=runtime", at: now)
            }
        } else {
            state.projection.isBroadcasting = false
            state.projection.hasExternalDisplay = false
            state.projection.safetyNotice = "未检测到外接屏幕，未开始投射"
            if canWriteSupport {
                state.support.record(kind: .projectionStartFailed, detail: "reason=noExternalDisplay", at: now)
            }
        }
    }

    static func startFailed(
        reason: ProjectionStartFailureReason,
        state: inout LiveRuntimeState
    ) {
        state.projection.isBroadcasting = false
        switch reason {
        case .noTargetScreen, .externalDisplayUnavailable:
            state.projection.hasExternalDisplay = false
            state.projection.safetyNotice = "未检测到外接屏幕，未开始投射"
        }
    }

    static func externalDisplayLost(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        canWriteSupport: Bool,
        now: Date
    ) {
        let wasBroadcasting = state.projection.isBroadcasting
        state.projection.isBroadcasting = false
        state.projection.hasExternalDisplay = false
        if wasBroadcasting {
            state.projection.safetyNotice = "副屏已断开，投射已停止"
        }
        guard wasBroadcasting else { return }
        if state.projection.lastDisplayLostAt == nil {
            state.projection.lastDisplayLostAt = now
            if canWriteSupport {
                state.support.record(kind: .projectionLost, detail: "state=displayLost", at: now)
            }
        }
        effects.append(.stopProjection)
    }

    static func externalDisplayAvailable(state: inout LiveRuntimeState) {
        state.projection.hasExternalDisplay = true
        state.projection.safetyNotice = nil
        state.projection.lastDisplayLostAt = nil
    }

    static func externalDisplayUnavailable(
        state: inout LiveRuntimeState,
        effects: inout [LiveRuntimeEffect],
        now: Date
    ) {
        let wasBroadcasting = state.projection.isBroadcasting
        state.projection.isBroadcasting = false
        state.projection.hasExternalDisplay = false
        if wasBroadcasting {
            state.projection.safetyNotice = "副屏已断开，投射已停止"
            if state.projection.lastDisplayLostAt == nil {
                state.projection.lastDisplayLostAt = now
            }
            effects.append(.stopProjection)
        } else {
            state.projection.lastDisplayLostAt = nil
        }
    }
}
