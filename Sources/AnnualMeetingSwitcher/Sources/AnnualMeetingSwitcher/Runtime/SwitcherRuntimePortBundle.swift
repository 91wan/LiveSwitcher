struct SwitcherRuntimePortBundle {
    let mediaPlaybackPort = ClosureMediaPlaybackPort()
    let bgmPlaybackPort = ClosureBGMPlaybackPort()
    let bgmTimerPort = ClosureBGMTimerPort()
    let projectionPort = ClosureProjectionPort()
    let pptPort = ClosurePPTEventTapPort()
    let automationNoticePort = ClosureAutomationNoticePort()
    let supportPort = ClosureSupportEventPort()
    let automationPort = ClosureAutomationPort()
    let presentationQueryPort = ClosurePresentationQueryPort()
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
            automationNotice: automationNoticePort,
            presentationQuery: presentationQueryPort,
            audioRouting: audioRoutingPort,
            imageAssets: imageAssetPort,
            persistence: persistencePort,
            support: supportPort
        )
    }
}
