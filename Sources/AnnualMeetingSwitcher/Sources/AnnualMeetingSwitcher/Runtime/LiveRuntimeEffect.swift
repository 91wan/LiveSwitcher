import Foundation

enum LiveRuntimeEffect: Equatable {
    case loadMedia(URL, generation: Int)
    case playMedia(generation: Int)
    case pauseMedia(generation: Int)
    case restartMedia(generation: Int)
    case stopMedia(generation: Int)
    case setMediaVolume(Float, fade: TimeInterval, generation: Int)

    case prepareBGM(BGMItem, generation: Int)
    case playBGM(generation: Int)
    case pauseBGM(generation: Int)
    case stopBGM(fade: TimeInterval, generation: Int)
    case setBGMVolume(Float, fade: TimeInterval, generation: Int)
    case startBGMTimer(generation: Int)
    case stopBGMTimer(generation: Int)

    case startProjection
    case stopProjection
    case showOutputWindow
    case hideOutputWindow

    case startPPTEventTap
    case stopPPTEventTap(reason: PPTStopReason)

    case runAppleScript(script: String, action: String)
    case showAutomationNotice(AutomationRuntimeNotice)
    case expireAutomationNotice(UUID, at: Date)

    case applyAudioRouting(reason: AudioRoutingRuntimeChangeReason)
    case savePersistentState
    case recordSupportEvent(LiveSupportEvent)
}

protocol MediaPlaybackPort {
    func load(url: URL, generation: Int)
    func play(generation: Int)
    func pause(generation: Int)
    func restart(generation: Int)
    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int)
}

protocol BGMPlaybackPort {
    func prepare(item: BGMItem, generation: Int)
    func play(generation: Int)
    func pause(generation: Int)
    func stop(fade: TimeInterval, generation: Int)
    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int)
}

protocol ProjectionPort {
    var hasExternalDisplay: Bool { get }
    func show()
    func hide()
}

protocol PPTEventTapPort {
    func start()
    func stop(reason: PPTStopReason)
}

protocol AutomationPort {
    func run(script: String, action: String)
}

protocol PersistencePort {
    func save()
}

protocol SupportEventPort {
    func record(_ event: LiveSupportEvent)
}

final class LiveRuntimeEffectRunner {
    private(set) var recordedEffects: [LiveRuntimeEffect] = []
    private let recordsOnly: Bool

    init(recordsOnly: Bool = true) {
        self.recordsOnly = recordsOnly
    }

    static func recording() -> LiveRuntimeEffectRunner {
        LiveRuntimeEffectRunner(recordsOnly: true)
    }

    func run(
        _ effects: [LiveRuntimeEffect],
        currentState: @escaping () -> LiveRuntimeState,
        dispatch: @escaping (LiveRuntimeAction) -> Void
    ) {
        recordedEffects.append(contentsOf: effects)
        guard !recordsOnly else { return }
        _ = currentState
        _ = dispatch
    }
}
