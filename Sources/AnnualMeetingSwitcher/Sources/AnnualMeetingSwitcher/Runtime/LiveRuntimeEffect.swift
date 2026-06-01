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
    func stop(generation: Int)
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
    func start()
    func stop()
    func show()
    func hide()
}

extension ProjectionPort {
    func start() {
        show()
    }

    func stop() {
        hide()
    }
}

protocol PPTEventTapPort {
    func start()
    func stop(reason: PPTStopReason)
}

protocol AutomationPort {
    func run(script: String, action: String)
}

protocol BGMTimerPort {
    func start(generation: Int)
    func stop(generation: Int)
}

protocol AutomationNoticePort {
    func show(_ notice: AutomationRuntimeNotice)
    func expire(id: UUID, at date: Date)
}

protocol AudioRoutingPort {
    func apply(reason: AudioRoutingRuntimeChangeReason, state: LiveRuntimeState)
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
    private let media: MediaPlaybackPort?
    private let bgm: BGMPlaybackPort?
    private let projection: ProjectionPort?
    private let ppt: PPTEventTapPort?
    private let automation: AutomationPort?
    private let bgmTimer: BGMTimerPort?
    private let automationNotice: AutomationNoticePort?
    private let audioRouting: AudioRoutingPort?
    private let persistence: PersistencePort?
    private let support: SupportEventPort?

    init(
        recordsOnly: Bool = true,
        media: MediaPlaybackPort? = nil,
        bgm: BGMPlaybackPort? = nil,
        projection: ProjectionPort? = nil,
        ppt: PPTEventTapPort? = nil,
        automation: AutomationPort? = nil,
        bgmTimer: BGMTimerPort? = nil,
        automationNotice: AutomationNoticePort? = nil,
        audioRouting: AudioRoutingPort? = nil,
        persistence: PersistencePort? = nil,
        support: SupportEventPort? = nil
    ) {
        self.recordsOnly = recordsOnly
        self.media = media
        self.bgm = bgm
        self.projection = projection
        self.ppt = ppt
        self.automation = automation
        self.bgmTimer = bgmTimer
        self.automationNotice = automationNotice
        self.audioRouting = audioRouting
        self.persistence = persistence
        self.support = support
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
        _ = dispatch
        effects.forEach { run($0, currentState: currentState) }
    }

    private func run(_ effect: LiveRuntimeEffect, currentState: () -> LiveRuntimeState) {
        switch effect {
        case .loadMedia(let url, let generation):
            media?.load(url: url, generation: generation)
        case .playMedia(let generation):
            media?.play(generation: generation)
        case .pauseMedia(let generation):
            media?.pause(generation: generation)
        case .restartMedia(let generation):
            media?.restart(generation: generation)
        case .stopMedia(let generation):
            media?.stop(generation: generation)
        case .setMediaVolume(let volume, let fade, let generation):
            media?.setVolume(volume, fade: fade, generation: generation)

        case .prepareBGM(let item, let generation):
            bgm?.prepare(item: item, generation: generation)
        case .playBGM(let generation):
            bgm?.play(generation: generation)
        case .pauseBGM(let generation):
            bgm?.pause(generation: generation)
        case .stopBGM(let fade, let generation):
            bgm?.stop(fade: fade, generation: generation)
        case .setBGMVolume(let volume, let fade, let generation):
            bgm?.setVolume(volume, fade: fade, generation: generation)
        case .startBGMTimer(let generation):
            bgmTimer?.start(generation: generation)
        case .stopBGMTimer(let generation):
            bgmTimer?.stop(generation: generation)

        case .startProjection:
            projection?.start()
        case .stopProjection:
            projection?.stop()
        case .showOutputWindow:
            projection?.show()
        case .hideOutputWindow:
            projection?.hide()

        case .startPPTEventTap:
            ppt?.start()
        case .stopPPTEventTap(let reason):
            ppt?.stop(reason: reason)

        case .runAppleScript(let script, let action):
            automation?.run(script: script, action: action)
        case .showAutomationNotice(let notice):
            automationNotice?.show(notice)
        case .expireAutomationNotice(let id, let date):
            automationNotice?.expire(id: id, at: date)

        case .applyAudioRouting(let reason):
            audioRouting?.apply(reason: reason, state: currentState())
        case .savePersistentState:
            persistence?.save()
        case .recordSupportEvent(let event):
            support?.record(event)
        }
    }
}
