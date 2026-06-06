import Foundation

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
    func seekToBeginning(generation: Int)
    func seek(toProgress progress: Double, generation: Int)
    func setPlayMode(_ playMode: BGMPlayMode, generation: Int?)
}

protocol ProjectionPort {
    var hasExternalDisplay: Bool { get }
    func start()
    func stop()
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

protocol PresentationQueryPort {
    func scan(id: UUID, context: LiveRuntimeEffectExecutionContext)
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

protocol SupportEventPort {
    func record(_ event: LiveSupportEvent)
}
