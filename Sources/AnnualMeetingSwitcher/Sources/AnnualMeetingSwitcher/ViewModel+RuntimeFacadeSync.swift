import Foundation

@MainActor
extension SwitcherViewModel {
    func syncAutomationNoticeFacadeFromRuntime() {
        guard runtime.bridgeMode.owns(.automationNotice) else { return }

        let notice = runtime.state.automation.notice
        if notice == nil {
            cancelAutomationNoticeExpiryTask()
        }
        automationRuntimeNotice = notice
    }

    func syncSupportFacadeFromRuntime() {
        applySupportEventsProjectionFromRuntime(runtime.state.support.events)
    }

    func syncPPTFacadeFromRuntime() {
        guard runtime.bridgeMode.owns(.ppt) else { return }

        isPageInterceptEnabled = runtime.state.ppt.isEventTapActive
    }

    func syncProjectionFacadeFromRuntime() {
        guard runtime.bridgeMode.owns(.projection) else { return }

        isBroadcasting = runtime.state.projection.isBroadcasting
        broadcastSafetyNotice = runtime.state.projection.safetyNotice
    }

    func syncBGMFacadeFromRuntime() {
        guard runtime.bridgeMode.owns(.bgm) else { return }

        let bgm = runtime.state.bgm
        currentBGMItem = bgm.currentItem
        isBGMPlaying = bgm.isPlaying
        bgmProgress = bgm.progress
        bgmCurrentTime = bgm.currentTime
        bgmDuration = bgm.duration
        bgmPlayMode = bgm.playMode
    }
}
