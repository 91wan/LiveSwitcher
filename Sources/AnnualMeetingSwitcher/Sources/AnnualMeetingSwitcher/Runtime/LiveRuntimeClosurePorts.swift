import Foundation

final class ClosureAudioRoutingPort: AudioRoutingPort {
    var applyHandler: ((AudioRoutingRuntimeChangeReason, LiveRuntimeState) -> Void)?

    func apply(reason: AudioRoutingRuntimeChangeReason, state: LiveRuntimeState) {
        applyHandler?(reason, state)
    }
}

final class ClosureMediaPlaybackPort: MediaPlaybackPort {
    var loadHandler: ((URL, Int) -> Void)?
    var playHandler: ((Int) -> Void)?
    var pauseHandler: ((Int) -> Void)?
    var restartHandler: ((Int) -> Void)?
    var seekToStartHandler: ((Int) -> Void)?
    var seekToEndHandler: ((Int) -> Void)?
    var stopHandler: ((Int) -> Void)?
    var setVolumeHandler: ((Float, TimeInterval, Int) -> Void)?

    func load(url: URL, generation: Int) {
        loadHandler?(url, generation)
    }

    func play(generation: Int) {
        playHandler?(generation)
    }

    func pause(generation: Int) {
        pauseHandler?(generation)
    }

    func restart(generation: Int) {
        restartHandler?(generation)
    }

    func seekToStart(generation: Int) {
        seekToStartHandler?(generation)
    }

    func seekToEnd(generation: Int) {
        seekToEndHandler?(generation)
    }

    func stop(generation: Int) {
        stopHandler?(generation)
    }

    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) {
        setVolumeHandler?(volume, fade, generation)
    }
}

final class ClosureBGMPlaybackPort: BGMPlaybackPort {
    var prepareHandler: ((BGMItem, Int) -> Void)?
    var playHandler: ((Int) -> Void)?
    var pauseHandler: ((Int) -> Void)?
    var stopHandler: ((TimeInterval, Int) -> Void)?
    var setVolumeHandler: ((Float, TimeInterval, Int) -> Void)?
    var seekToBeginningHandler: ((Int) -> Void)?
    var seekToProgressHandler: ((Double, Int) -> Void)?
    var setPlayModeHandler: ((BGMPlayMode, Int?) -> Void)?

    func prepare(item: BGMItem, generation: Int) {
        prepareHandler?(item, generation)
    }

    func play(generation: Int) {
        playHandler?(generation)
    }

    func pause(generation: Int) {
        pauseHandler?(generation)
    }

    func stop(fade: TimeInterval, generation: Int) {
        stopHandler?(fade, generation)
    }

    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) {
        setVolumeHandler?(volume, fade, generation)
    }

    func seekToBeginning(generation: Int) {
        seekToBeginningHandler?(generation)
    }

    func seek(toProgress progress: Double, generation: Int) {
        seekToProgressHandler?(progress, generation)
    }

    func setPlayMode(_ playMode: BGMPlayMode, generation: Int?) {
        setPlayModeHandler?(playMode, generation)
    }
}

final class ClosureBGMTimerPort: BGMTimerPort {
    var startHandler: ((Int) -> Void)?
    var stopHandler: ((Int) -> Void)?

    func start(generation: Int) {
        startHandler?(generation)
    }

    func stop(generation: Int) {
        stopHandler?(generation)
    }
}

final class ClosureAutomationNoticePort: AutomationNoticePort {
    var showHandler: ((AutomationRuntimeNotice) -> Void)?
    var expireHandler: ((UUID, Date) -> Void)?

    func show(_ notice: AutomationRuntimeNotice) {
        showHandler?(notice)
    }

    func expire(id: UUID, at date: Date) {
        expireHandler?(id, date)
    }
}

final class ClosureSupportEventPort: SupportEventPort {
    var recordHandler: ((LiveSupportEvent) -> Void)?

    func record(_ event: LiveSupportEvent) {
        recordHandler?(event)
    }
}

final class ClosureAutomationPort: AutomationPort {
    var runHandler: ((String, String) -> Void)?

    func run(script: String, action: String) {
        runHandler?(script, action)
    }
}

final class ClosurePresentationQueryPort: PresentationQueryPort {
    var scanHandler: ((UUID, LiveRuntimeEffectExecutionContext) -> Void)?

    func scan(id: UUID, context: LiveRuntimeEffectExecutionContext) {
        scanHandler?(id, context)
    }
}

final class ClosureProgramActivationPort: ProgramActivationPort {
    var executeHandler: ((UUID, ProgramActivationPlan, LiveRuntimeEffectExecutionContext) -> Void)?

    func execute(id: UUID, plan: ProgramActivationPlan, context: LiveRuntimeEffectExecutionContext) {
        executeHandler?(id, plan, context)
    }
}

final class ClosureProjectionPort: ProjectionPort {
    var hasExternalDisplayHandler: (() -> Bool)?
    var startHandler: (() -> Void)?
    var stopHandler: (() -> Void)?
    var showHandler: (() -> Void)?
    var hideHandler: (() -> Void)?

    var hasExternalDisplay: Bool {
        hasExternalDisplayHandler?() ?? false
    }

    func start() {
        startHandler?()
    }

    func stop() {
        stopHandler?()
    }

    func show() {
        showHandler?()
    }

    func hide() {
        hideHandler?()
    }
}

final class ClosureImageAssetPort: ImageAssetPort {
    var loadBackgroundImageHandler: ((URL?) -> Void)?
    var loadCornerLogoImageHandler: ((URL?) -> Void)?

    func loadBackgroundImage(from url: URL?) {
        loadBackgroundImageHandler?(url)
    }

    func loadCornerLogoImage(from url: URL?) {
        loadCornerLogoImageHandler?(url)
    }
}

final class ClosurePersistencePort: PersistencePort {
    var saveHandler: (() -> Void)?
    var saveConsoleModeHandler: ((ConsoleMode) -> Void)?
    var saveThemeOverrideHandler: ((ThemeOverride) -> Void)?
    var saveAudioStrategyHandler: ((AudioStrategy) -> Void)?
    var saveSpeakerModeHandler: ((Bool) -> Void)?
    var saveBGMPlayModeHandler: ((BGMPlayMode) -> Void)?
    var saveAutoPlayNextVideoOnEndHandler: ((Bool) -> Void)?
    var saveAutoAdvanceAtScheduledTimeHandler: ((Bool) -> Void)?
    var saveShowAgendaTimelineHandler: ((Bool) -> Void)?
    var saveCornerLogoPositionHandler: ((CornerLogoPosition) -> Void)?

    func save() {
        saveHandler?()
    }

    func saveConsoleMode(_ mode: ConsoleMode) {
        saveConsoleModeHandler?(mode)
    }

    func saveThemeOverride(_ theme: ThemeOverride) {
        saveThemeOverrideHandler?(theme)
    }

    func saveAudioStrategy(_ strategy: AudioStrategy) {
        saveAudioStrategyHandler?(strategy)
    }

    func saveSpeakerMode(_ isEnabled: Bool) {
        saveSpeakerModeHandler?(isEnabled)
    }

    func saveBGMPlayMode(_ playMode: BGMPlayMode) {
        saveBGMPlayModeHandler?(playMode)
    }

    func saveAutoPlayNextVideoOnEnd(_ isEnabled: Bool) {
        saveAutoPlayNextVideoOnEndHandler?(isEnabled)
    }

    func saveAutoAdvanceAtScheduledTime(_ isEnabled: Bool) {
        saveAutoAdvanceAtScheduledTimeHandler?(isEnabled)
    }

    func saveShowAgendaTimeline(_ isEnabled: Bool) {
        saveShowAgendaTimelineHandler?(isEnabled)
    }

    func saveCornerLogoPosition(_ position: CornerLogoPosition) {
        saveCornerLogoPositionHandler?(position)
    }
}

final class ClosurePPTEventTapPort: PPTEventTapPort {
    var startHandler: (() -> Void)?
    var stopHandler: ((PPTStopReason) -> Void)?

    func start() {
        startHandler?()
    }

    func stop(reason: PPTStopReason) {
        stopHandler?(reason)
    }
}
