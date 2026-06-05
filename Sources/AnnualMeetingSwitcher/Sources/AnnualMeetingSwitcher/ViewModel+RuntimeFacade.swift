import Foundation

@MainActor
extension SwitcherViewModel {
    func dispatchRuntimeFacadeAction(_ action: LiveRuntimeAction) {
        let syncOptions = LiveRuntimeFacadeSyncPolicy.options(for: action)
        syncRuntimeEnvironmentFromFacade()
        syncRuntimeStateFromFacade(
            clearActionLog: false,
            dispatchAudioInputsChanged: syncOptions.dispatchAudioInputsChanged
        )
        runtime.dispatch(action)
        if syncOptions.syncBGM {
            syncBGMFacadeFromRuntime()
        }
        if syncOptions.syncProjection {
            syncProjectionFacadeFromRuntime()
        }
        if syncOptions.syncPPT {
            syncPPTFacadeFromRuntime()
        }
        if syncOptions.syncAutomationNotice {
            syncAutomationNoticeFacadeFromRuntime()
        }
        if syncOptions.syncSupport {
            syncSupportFacadeFromRuntime()
        }
    }

    private func syncRuntimeEnvironmentFromFacade() {
        runtime.updateEnvironment(
            LiveRuntimeEnvironment(
                now: Date(),
                speakerModeDuckedRatio: speakerModeDuckedRatio,
                liveAudioFadeDuration: liveAudioFadeDuration,
                bridgeMode: runtime.bridgeMode
            )
        )
    }

    var runtimeConnectedPortKinds: Set<LiveRuntimeEffectPortKind> {
        runtime.connectedPortKinds
    }

    var runtimeBridgeMode: LiveRuntimeBridgeMode {
        runtime.bridgeMode
    }

    func dispatchRuntimeMediaCallback(_ makeAction: (Int) -> LiveRuntimeAction) {
        syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)
        guard let generation = activeRuntimeMediaGenerationForCallbacks else { return }
        guard currentProgramItem?.sourceKind == .media else { return }
        guard avCoordinator.currentURL == activeRuntimeMediaURLForCallbacks else { return }
        runtime.dispatch(makeAction(generation))
    }

    @discardableResult
    func dispatchRuntimeBGMCallback(_ makeAction: (Int) -> LiveRuntimeAction) -> Bool {
        syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)
        guard let generation = activeRuntimeBGMGenerationForCallbacks else { return false }
        guard currentBGMItem?.id == activeRuntimeBGMItemIDForCallbacks else { return false }
        guard currentBGMItem?.url == activeRuntimeBGMURLForCallbacks else { return false }
        runtime.dispatch(makeAction(generation))
        syncBGMFacadeFromRuntime()
        return true
    }

    func dispatchRuntimeBGMProgressCallback(time: Double, duration: Double?) {
        dispatchRuntimeBGMCallback {
            .bgmProgressUpdated(time: time, duration: duration, generation: $0)
        }
    }

    func syncRuntimeAudioInputsFromFacade(reason: AudioRoutingRuntimeChangeReason?) {
        syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: true)
        if let reason {
            applyAudioRoutingForRuntimeChange(reason: reason, runtimeState: runtime.state)
        }
    }
}
