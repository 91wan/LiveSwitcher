final class LiveRuntimeEffectRunner {
    private(set) var recordedEffects: [LiveRuntimeEffect] = []
    private let recordsOnly: Bool
    private let media: MediaPlaybackPort?
    private let bgm: BGMPlaybackPort?
    private let projection: ProjectionPort?
    private let ppt: PPTEventTapPort?
    private let automation: AutomationPort?
    private let bgmTimer: BGMTimerPort?
    private let panicDelay: PanicDelayPort?
    private let automationNotice: AutomationNoticePort?
    private let presentationQuery: PresentationQueryPort?
    private let programActivation: ProgramActivationPort?
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
        panicDelay: PanicDelayPort? = nil,
        automationNotice: AutomationNoticePort? = nil,
        presentationQuery: PresentationQueryPort? = nil,
        programActivation: ProgramActivationPort? = nil,
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
        self.panicDelay = panicDelay
        self.automationNotice = automationNotice
        self.presentationQuery = presentationQuery
        self.programActivation = programActivation
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
        if panicDelay != nil { kinds.insert(.panicDelay) }
        if automationNotice != nil { kinds.insert(.automationNotice) }
        if presentationQuery != nil { kinds.insert(.presentationQuery) }
        if programActivation != nil { kinds.insert(.programActivation) }
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
        recordedEffects.append(contentsOf: effects.map(\.redactedForRecording))
        guard !recordsOnly else { return }

        let context = LiveRuntimeEffectExecutionContext(
            currentState: currentState,
            dispatch: dispatch
        )

        effects.forEach { run($0, context: context) }
    }

    private func run(_ effect: LiveRuntimeEffect, context: LiveRuntimeEffectExecutionContext) {
        switch effect {
        case .loadMedia(let url, let generation):
            guard isCurrentMediaGeneration(generation, currentState: context.currentState) else { return }
            media?.load(url: url, generation: generation)
        case .playMedia(let generation):
            guard isCurrentMediaGeneration(generation, currentState: context.currentState) else { return }
            media?.play(generation: generation)
        case .pauseMedia(let generation):
            guard isCurrentMediaGeneration(generation, currentState: context.currentState) else { return }
            media?.pause(generation: generation)
        case .restartMedia(let generation):
            guard isCurrentMediaGeneration(generation, currentState: context.currentState) else { return }
            media?.restart(generation: generation)
        case .seekMediaToStart(let generation):
            guard isCurrentMediaGeneration(generation, currentState: context.currentState) else { return }
            media?.seekToStart(generation: generation)
        case .seekMediaToEnd(let generation):
            guard isCurrentMediaGeneration(generation, currentState: context.currentState) else { return }
            media?.seekToEnd(generation: generation)
        case .stopMedia(let generation):
            guard isCurrentMediaGeneration(generation, currentState: context.currentState) else { return }
            media?.stop(generation: generation)
        case .setMediaVolume(let volume, let fade, let generation):
            guard isCurrentMediaGeneration(generation, currentState: context.currentState) else { return }
            media?.setVolume(volume, fade: fade, generation: generation)

        case .prepareBGM(let item, let generation):
            guard isCurrentBGMGeneration(generation, currentState: context.currentState) else { return }
            bgm?.prepare(item: item, generation: generation)
        case .playBGM(let generation):
            guard isCurrentBGMGeneration(generation, currentState: context.currentState) else { return }
            bgm?.play(generation: generation)
        case .pauseBGM(let generation):
            guard isCurrentBGMGeneration(generation, currentState: context.currentState) else { return }
            bgm?.pause(generation: generation)
        case .stopBGM(let fade, let generation):
            guard isCurrentBGMGeneration(generation, currentState: context.currentState) else { return }
            bgm?.stop(fade: fade, generation: generation)
        case .setBGMVolume(let volume, let fade, let generation):
            guard isCurrentBGMGeneration(generation, currentState: context.currentState) else { return }
            bgm?.setVolume(volume, fade: fade, generation: generation)
        case .seekBGMToBeginning(let generation):
            guard isCurrentBGMGeneration(generation, currentState: context.currentState) else { return }
            bgm?.seekToBeginning(generation: generation)
        case .seekBGMToProgress(let progress, let generation):
            guard isCurrentBGMGeneration(generation, currentState: context.currentState) else { return }
            bgm?.seek(toProgress: progress, generation: generation)
        case .setBGMPlayMode(let playMode, let generation):
            if let generation {
                guard isCurrentBGMGeneration(generation, currentState: context.currentState) else { return }
            }
            bgm?.setPlayMode(playMode, generation: generation)
        case .startBGMTimer(let generation):
            guard isCurrentBGMGeneration(generation, currentState: context.currentState) else { return }
            bgmTimer?.start(generation: generation)
        case .stopBGMTimer(let generation):
            guard isCurrentBGMGeneration(generation, currentState: context.currentState) else { return }
            bgmTimer?.stop(generation: generation)
        case .schedulePanicBGMPause(let generation, let snapshot, let delay):
            panicDelay?.scheduleBGMPause(generation: generation, snapshot: snapshot, delay: delay, context: context)
        case .cancelPanicBGMPause(let generation):
            panicDelay?.cancelBGMPause(generation: generation)

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
        case .scanPresentationQuery(let id):
            presentationQuery?.scan(id: id, context: context)
        case .executeProgramActivation(let id, let plan):
            programActivation?.execute(id: id, plan: plan, context: context)

        case .applyAudioRouting(let reason):
            audioRouting?.apply(reason: reason, state: context.currentState())
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

    private func isCurrentBGMGeneration(_ generation: Int, currentState: () -> LiveRuntimeState) -> Bool {
        currentState().bgm.generation == generation
    }
}
