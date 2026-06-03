import Foundation

enum LiveRuntimeEffect: Equatable {
    case loadMedia(URL, generation: Int)
    case playMedia(generation: Int)
    case pauseMedia(generation: Int)
    case restartMedia(generation: Int)
    case seekMediaToStart(generation: Int)
    case seekMediaToEnd(generation: Int)
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
    case loadBackgroundImage(URL?)
    case loadCornerLogoImage(URL?)
    case saveConsoleMode(ConsoleMode)
    case saveThemeOverride(ThemeOverride)
    case saveAudioStrategy(AudioStrategy)
    case saveSpeakerMode(Bool)
    case saveBGMPlayMode(BGMPlayMode)
    case saveAutoPlayNextVideoOnEnd(Bool)
    case saveAutoAdvanceAtScheduledTime(Bool)
    case saveShowAgendaTimeline(Bool)
    case saveCornerLogoPosition(CornerLogoPosition)
    case savePersistentState
    case recordSupportEvent(LiveSupportEvent)
}

enum LiveRuntimeEffectPortKind: String, CaseIterable {
    case media
    case bgm
    case projection
    case ppt
    case automation
    case bgmTimer
    case automationNotice
    case audioRouting
    case imageAssets
    case persistence
    case support
}

protocol MediaPlaybackPort {
    func load(url: URL, generation: Int)
    func play(generation: Int)
    func pause(generation: Int)
    func restart(generation: Int)
    func seekToStart(generation: Int)
    func seekToEnd(generation: Int)
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

protocol ImageAssetPort {
    func loadBackgroundImage(from url: URL?)
    func loadCornerLogoImage(from url: URL?)
}

protocol PersistencePort {
    func save()
    func saveConsoleMode(_ mode: ConsoleMode)
    func saveThemeOverride(_ theme: ThemeOverride)
    func saveAudioStrategy(_ strategy: AudioStrategy)
    func saveSpeakerMode(_ isEnabled: Bool)
    func saveBGMPlayMode(_ playMode: BGMPlayMode)
    func saveAutoPlayNextVideoOnEnd(_ isEnabled: Bool)
    func saveAutoAdvanceAtScheduledTime(_ isEnabled: Bool)
    func saveShowAgendaTimeline(_ isEnabled: Bool)
    func saveCornerLogoPosition(_ position: CornerLogoPosition)
}

extension PersistencePort {
    func saveConsoleMode(_ mode: ConsoleMode) {
        save()
    }

    func saveThemeOverride(_ theme: ThemeOverride) {
        save()
    }

    func saveAudioStrategy(_ strategy: AudioStrategy) {
        save()
    }

    func saveSpeakerMode(_ isEnabled: Bool) {
        save()
    }

    func saveBGMPlayMode(_ playMode: BGMPlayMode) {
        save()
    }

    func saveAutoPlayNextVideoOnEnd(_ isEnabled: Bool) {
        save()
    }

    func saveAutoAdvanceAtScheduledTime(_ isEnabled: Bool) {
        save()
    }

    func saveShowAgendaTimeline(_ isEnabled: Bool) {
        save()
    }

    func saveCornerLogoPosition(_ position: CornerLogoPosition) {
        save()
    }
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
    private let imageAssets: ImageAssetPort?
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
        imageAssets: ImageAssetPort? = nil,
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
        self.imageAssets = imageAssets
        self.persistence = persistence
        self.support = support
    }

    static func recording() -> LiveRuntimeEffectRunner {
        LiveRuntimeEffectRunner(recordsOnly: true)
    }

    var connectedPortKinds: Set<LiveRuntimeEffectPortKind> {
        var kinds = Set<LiveRuntimeEffectPortKind>()
        if media != nil { kinds.insert(.media) }
        if bgm != nil { kinds.insert(.bgm) }
        if projection != nil { kinds.insert(.projection) }
        if ppt != nil { kinds.insert(.ppt) }
        if automation != nil { kinds.insert(.automation) }
        if bgmTimer != nil { kinds.insert(.bgmTimer) }
        if automationNotice != nil { kinds.insert(.automationNotice) }
        if audioRouting != nil { kinds.insert(.audioRouting) }
        if imageAssets != nil { kinds.insert(.imageAssets) }
        if persistence != nil { kinds.insert(.persistence) }
        if support != nil { kinds.insert(.support) }
        return kinds
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
            guard isCurrentMediaGeneration(generation, currentState: currentState) else { return }
            media?.load(url: url, generation: generation)
        case .playMedia(let generation):
            guard isCurrentMediaGeneration(generation, currentState: currentState) else { return }
            media?.play(generation: generation)
        case .pauseMedia(let generation):
            guard isCurrentMediaGeneration(generation, currentState: currentState) else { return }
            media?.pause(generation: generation)
        case .restartMedia(let generation):
            guard isCurrentMediaGeneration(generation, currentState: currentState) else { return }
            media?.restart(generation: generation)
        case .seekMediaToStart(let generation):
            guard isCurrentMediaGeneration(generation, currentState: currentState) else { return }
            media?.seekToStart(generation: generation)
        case .seekMediaToEnd(let generation):
            guard isCurrentMediaGeneration(generation, currentState: currentState) else { return }
            media?.seekToEnd(generation: generation)
        case .stopMedia(let generation):
            guard isCurrentMediaGeneration(generation, currentState: currentState) else { return }
            media?.stop(generation: generation)
        case .setMediaVolume(let volume, let fade, let generation):
            guard isCurrentMediaGeneration(generation, currentState: currentState) else { return }
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
        case .loadBackgroundImage(let url):
            imageAssets?.loadBackgroundImage(from: url)
        case .loadCornerLogoImage(let url):
            imageAssets?.loadCornerLogoImage(from: url)
        case .saveConsoleMode(let mode):
            persistence?.saveConsoleMode(mode)
        case .saveThemeOverride(let theme):
            persistence?.saveThemeOverride(theme)
        case .saveAudioStrategy(let strategy):
            persistence?.saveAudioStrategy(strategy)
        case .saveSpeakerMode(let isEnabled):
            persistence?.saveSpeakerMode(isEnabled)
        case .saveBGMPlayMode(let playMode):
            persistence?.saveBGMPlayMode(playMode)
        case .saveAutoPlayNextVideoOnEnd(let isEnabled):
            persistence?.saveAutoPlayNextVideoOnEnd(isEnabled)
        case .saveAutoAdvanceAtScheduledTime(let isEnabled):
            persistence?.saveAutoAdvanceAtScheduledTime(isEnabled)
        case .saveShowAgendaTimeline(let isEnabled):
            persistence?.saveShowAgendaTimeline(isEnabled)
        case .saveCornerLogoPosition(let position):
            persistence?.saveCornerLogoPosition(position)
        case .savePersistentState:
            persistence?.save()
        case .recordSupportEvent(let event):
            support?.record(event)
        }
    }

    private func isCurrentMediaGeneration(_ generation: Int, currentState: () -> LiveRuntimeState) -> Bool {
        currentState().media.generation == generation
    }
}
