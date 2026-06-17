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
        if syncOptions.syncProgramQueue {
            syncProgramQueueFacadeFromRuntime()
        }
        if syncOptions.syncCurrentProgram {
            syncCurrentProgramFacadeFromRuntime()
        }
        if syncOptions.syncPanic {
            syncPanicFacadeFromRuntime()
        }
    }

    private func syncRuntimeEnvironmentFromFacade() {
        runtime.updateEnvironment(
            LiveRuntimeEnvironment(
                now: Date(),
                speakerModeDuckedRatio: runtimeSpeakerModeDuckedRatio,
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

    @discardableResult
    func dispatchRuntimeMediaCallback(_ makeAction: (Int) -> LiveRuntimeAction) -> Bool {
        syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)
        guard let generation = validatedRuntimeMediaCallbackGeneration() else { return false }
        runtime.dispatch(makeAction(generation))
        return true
    }

    @discardableResult
    func dispatchRuntimeBGMCallback(_ makeAction: (Int) -> LiveRuntimeAction) -> Bool {
        syncRuntimeStateFromFacade(clearActionLog: false, dispatchAudioInputsChanged: false)
        guard let generation = validatedRuntimeBGMCallbackGeneration() else { return false }
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
