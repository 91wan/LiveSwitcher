struct SwitcherRuntimePortBundle {
    let mediaPlaybackPort = ClosureMediaPlaybackPort()
    let bgmPlaybackPort = ClosureBGMPlaybackPort()
    let bgmTimerPort = ClosureBGMTimerPort()
    let panicDelayPort = ClosurePanicDelayPort()
    let projectionPort = ClosureProjectionPort()
    let pptPort = ClosurePPTEventTapPort()
    let automationNoticePort = ClosureAutomationNoticePort()
    let supportPort = ClosureSupportEventPort()
    let automationPort = ClosureAutomationPort()
    let presentationQueryPort = ClosurePresentationQueryPort()
    let programActivationPort = ClosureProgramActivationPort()
    let audioRoutingPort = ClosureAudioRoutingPort()
    let imageAssetPort = ClosureImageAssetPort()
    let persistencePort = ClosurePersistencePort()

    func makeEffectRunner() -> LiveRuntimeEffectRunner {
        LiveRuntimeEffectRunner(
            recordsOnly: false,
            media: mediaPlaybackPort,
            bgm: bgmPlaybackPort,
            projection: projectionPort,
            ppt: pptPort,
            automation: automationPort,
            bgmTimer: bgmTimerPort,
            panicDelay: panicDelayPort,
            automationNotice: automationNoticePort,
            presentationQuery: presentationQueryPort,
            programActivation: programActivationPort,
            audioRouting: audioRoutingPort,
            imageAssets: imageAssetPort,
            persistence: persistencePort,
            support: supportPort
        )
    }
}
