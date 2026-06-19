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
        environment: LiveRuntimeEnvironment = .productionAudioOwned()
    ) {
        self.state = initialState
        self.effectRunner = .recording()
        self.environment = environment
    }

    init(
        initialState: LiveRuntimeState = LiveRuntimeState(),
        effectRunner: LiveRuntimeEffectRunner,
        environment: LiveRuntimeEnvironment
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

    var bridgeMode: LiveRuntimeBridgeMode {
        environment.bridgeMode
    }

    func dispatch(_ action: LiveRuntimeAction) {
        let oldState = state
        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: environment
        )
        state = mutation.state
        if LiveRuntimeActionLogPolicy.shouldLog(action) {
            actionLog.append(
                LiveRuntimeActionLogEntry(
                    timestamp: environment.now,
                    actionName: action.redactedName,
                    oldStateSummary: Self.summary(for: oldState),
                    newStateSummary: Self.summary(for: state)
                )
            )
        }
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

    func hydratePersistentOwnedState(_ persistentState: SwitcherPersistentState) {
        var nextState = state
        let bridgeMode = environment.bridgeMode

        if bridgeMode.owns(.audio) {
            nextState.audio.strategy = persistentState.audioStrategy
            nextState.audio.isSpeakerMode = persistentState.isSpeakerMode
        }

        if bridgeMode.owns(.bgm) {
            nextState.bgm.playMode = persistentState.bgmPlayMode
        }

        if bridgeMode.owns(.persistence) {
            nextState.mode = persistentState.consoleMode
            nextState.preferences = LiveRuntimePreferenceState(
                themeOverride: persistentState.themeOverride,
                activeWallpaperURL: persistentState.activeWallpaperURL,
                cornerLogoURL: persistentState.cornerLogoURL,
                autoPlayNextVideoOnEnd: persistentState.autoPlayNextVideoOnEnd,
                autoAdvanceAtScheduledTime: persistentState.autoAdvanceAtScheduledTime,
                showAgendaTimeline: persistentState.showAgendaTimeline,
                cornerLogoPosition: persistentState.cornerLogoPosition
            )
        }

        if bridgeMode.owns(.audio) {
            AudioRuntimeReducer.recalculateAudio(
                &nextState,
                speakerModeDuckedRatio: environment.speakerModeDuckedRatio
            )
        }

        state = nextState
    }

    private static func summary(for state: LiveRuntimeState) -> String {
        let programSummary: String
        if let currentID = state.program.currentID {
            programSummary = state.program.currentItem == nil
                ? "detached:\(currentID.uuidString)"
                : currentID.uuidString
        } else {
            programSummary = "none"
        }

        return [
            "mode=\(state.mode.rawValue)",
            "program=\(programSummary)",
            "queueCount=\(state.program.items.count)",
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

enum LiveRuntimeActionLogPolicy {
    static func shouldLog(_ action: LiveRuntimeAction) -> Bool {
        switch action {
        case .facadeAudioInputsChanged,
             .automationNoticeRequested,
             .automationNoticeExpired,
             .supportEventRecorded,
             .presentationQueryCompleted,
             .presentationQueryResultConsumed,
             .programActivationCompleted,
             .facadeLoadedProgramQueue,
             .bgmProgressUpdated,
             .mediaSeekCompleted,
             .panicBGMPauseDelayElapsed:
            return false
        default:
            return true
        }
    }
}
