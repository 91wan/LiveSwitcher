import Foundation
import Observation

@MainActor
@Observable
final class LiveRuntimeStore {
    private(set) var state: LiveRuntimeState
    private(set) var actionLog: [LiveRuntimeActionLogEntry] = []
    @ObservationIgnored
    private let effectRunner: LiveRuntimeEffectRunner
    @ObservationIgnored
    private var environment: LiveRuntimeEnvironment

    init(
        initialState: LiveRuntimeState = LiveRuntimeState(),
        effectRunner: LiveRuntimeEffectRunner = .recording(),
        environment: LiveRuntimeEnvironment = LiveRuntimeEnvironment()
    ) {
        self.state = initialState
        self.effectRunner = effectRunner
        self.environment = environment
    }

    var recordedEffects: [LiveRuntimeEffect] {
        effectRunner.recordedEffects
    }

    var connectedPortKinds: Set<LiveRuntimeEffectPortKind> {
        effectRunner.connectedPortKinds
    }

    func dispatch(_ action: LiveRuntimeAction) {
        let oldState = state
        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: environment
        )
        state = mutation.state
        actionLog.append(
            LiveRuntimeActionLogEntry(
                timestamp: environment.now,
                actionName: action.redactedName,
                oldStateSummary: Self.summary(for: oldState),
                newStateSummary: Self.summary(for: state)
            )
        )
        effectRunner.run(
            mutation.effects,
            currentState: { [weak self] in self?.state ?? LiveRuntimeState() },
            dispatch: { [weak self] action in self?.dispatch(action) }
        )
    }

    func updateEnvironment(_ environment: LiveRuntimeEnvironment) {
        self.environment = environment
    }

    func replaceStateForFacadeSync(_ state: LiveRuntimeState, clearActionLog: Bool = false) {
        self.state = state
        if clearActionLog {
            actionLog.removeAll()
        }
    }

    private static func summary(for state: LiveRuntimeState) -> String {
        [
            "mode=\(state.mode.rawValue)",
            "program=\(state.program.currentID?.uuidString ?? "none")",
            "mediaPlaying=\(state.media.isPlaying)",
            "bgm=\(state.bgm.currentID?.uuidString ?? "none")",
            "bgmPlaying=\(state.bgm.isPlaying)",
            "panic=\(state.panic.isActive)",
            "projection=\(state.projection.isBroadcasting)",
            "pptRequested=\(state.ppt.isRequested)",
            "pptActive=\(state.ppt.isEventTapActive)",
            "theme=\(state.preferences.themeOverride.rawValue)",
            "autoNext=\(state.preferences.autoPlayNextVideoOnEnd)",
            "autoAdvance=\(state.preferences.autoAdvanceAtScheduledTime)",
            "agendaTimeline=\(state.preferences.showAgendaTimeline)",
            "cornerLogo=\(state.preferences.cornerLogoPosition.rawValue)"
        ].joined(separator: ",")
    }
}
