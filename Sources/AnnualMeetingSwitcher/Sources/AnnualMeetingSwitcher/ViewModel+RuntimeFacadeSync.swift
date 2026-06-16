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

    func syncProgramQueueFacadeFromRuntime() {
        guard runtime.bridgeMode.owns(.programQueue) else { return }

        applyProgramQueueProjectionFromRuntime(runtime.state.program.items)
        reconcileCurrentProgramAfterProgramQueueProjection()
    }

    func syncCurrentProgramFacadeFromRuntime() {
        guard runtime.bridgeMode.owns(.programSelection) else { return }

        applyCurrentProgramProjectionFromRuntime(
            runtime.state.program.effectiveCurrentItem,
            switchedAt: runtime.state.program.currentSwitchedAt
        )
    }

    func syncPPTFacadeFromRuntime() {
        guard runtime.bridgeMode.owns(.ppt) else { return }

        isPageInterceptEnabled = runtime.state.ppt.isEventTapActive
    }

    func syncProjectionFacadeFromRuntime() {
        guard runtime.bridgeMode.owns(.projection) else { return }

        updateExternalDisplayAvailabilityForProjection(runtime.state.projection.hasExternalDisplay)
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

    func syncPanicFacadeFromRuntime() {
        guard runtime.bridgeMode.owns(.panic) else { return }

        applyPanicProjectionFromRuntime(
            isActive: runtime.state.panic.isActive,
            snapshot: runtime.state.panic.snapshot
        )
    }

    private func reconcileCurrentProgramAfterProgramQueueProjection() {
        guard !runtime.bridgeMode.owns(.programSelection) else { return }
        guard let currentProgramItem,
              let runtimeItem = programItems.first(where: { $0.id == currentProgramItem.id }),
              runtimeItem != currentProgramItem
        else { return }

        applyCurrentProgramProjectionFromRuntime(runtimeItem, switchedAt: currentProgramSwitchedAt)
    }
}
