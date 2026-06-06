import Foundation

@MainActor
extension SwitcherViewModel {
    func configureRuntimePortHandlers(_ ports: SwitcherRuntimePortBundle) {
        ports.supportPort.recordHandler = { [weak self] _ in
            self?.syncSupportFacadeFromRuntime()
        }
        ports.automationPort.runHandler = { [weak self] script, action in
            Task { @MainActor [weak self] in
                guard let self else { return }
                defer { testHooks.automationCommandDidFinish?() }
                do {
                    if let automationCommandRunner = testHooks.automationCommandRunner {
                        try automationCommandRunner(script, action)
                    } else {
                        try AppleScriptRunner.run(script, action: action)
                    }
                } catch {
                    self.handleAppleScriptFailure(error, action: action)
                }
            }
        }
        ports.presentationQueryPort.scanHandler = { [weak self] id, context in
            guard let self else { return }
            do {
                let result = try scanPresentationQueryForRuntimePort()
                context.dispatch(.presentationQueryCompleted(id: id, result: result))
            } catch {
                let sanitizedMessage = sanitizedAutomationFailureMessage(error)
                context.dispatch(.presentationQueryFailed(
                    id: id,
                    action: "keynote.scan.windows",
                    sanitizedMessage: sanitizedMessage
                ))
            }
        }
        ports.automationNoticePort.showHandler = { [weak self] notice in
            self?.cancelAutomationNoticeExpiryTask()
            self?.automationRuntimeNotice = notice
        }
        ports.automationNoticePort.expireHandler = { [weak self] id, date in
            guard let self else { return }
            cancelAutomationNoticeExpiryTask()
            cleanupBag.automationNoticeExpiryTaskNoticeID = id
            cleanupBag.automationNoticeExpiryTask = Task { @MainActor [weak self] in
                let delay = max(0, date.timeIntervalSinceNow)
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                guard !Task.isCancelled else { return }
                self?.expireAutomationNoticeFromScheduledTask(id: id)
            }
        }
        ports.projectionPort.hasExternalDisplayHandler = { [weak self] in
            self?.projectionService.hasExternalDisplay ?? false
        }
        ports.projectionPort.startHandler = { [weak self] in
            self?.showOutputWindowFromRuntimeProjection()
        }
        ports.projectionPort.stopHandler = { [weak self] in
            self?.hideOutputWindowFromRuntimeProjection()
        }
        ports.projectionPort.showHandler = { [weak self] in
            self?.showOutputWindowFromRuntimeProjection()
        }
        ports.projectionPort.hideHandler = { [weak self] in
            self?.hideOutputWindowFromRuntimeProjection()
        }
        ports.pptPort.startHandler = { [weak self] in
            self?.startPPTEventTapFromRuntime()
        }
        ports.pptPort.stopHandler = { [weak self] reason in
            self?.stopPPTEventTapFromRuntime(reason: reason)
        }
        ports.mediaPlaybackPort.loadHandler = { [weak self] url, generation in
            self?.setActiveRuntimeMediaCallbackIdentity(generation: generation, url: url)
            self?.avCoordinator.load(url: url)
        }
        ports.mediaPlaybackPort.playHandler = { [weak self] _ in
            self?.avCoordinator.play(reloadIfNeeded: false)
        }
        ports.mediaPlaybackPort.pauseHandler = { [weak self] _ in
            self?.avCoordinator.pause()
        }
        ports.mediaPlaybackPort.restartHandler = { [weak self] _ in
            self?.avCoordinator.restartFromBeginning()
        }
        ports.mediaPlaybackPort.seekToStartHandler = { [weak self] _ in
            self?.avCoordinator.seekToBeginning()
        }
        ports.mediaPlaybackPort.seekToEndHandler = { [weak self] _ in
            self?.avCoordinator.seekToEnd()
        }
        ports.mediaPlaybackPort.stopHandler = { [weak self] generation in
            self?.clearActiveRuntimeMediaCallbackIdentity(ifGeneration: generation)
            self?.avCoordinator.stop()
        }
        ports.mediaPlaybackPort.setVolumeHandler = { [weak self] volume, fade, _ in
            self?.fadeMediaVolume(to: volume, duration: fade)
        }
        ports.bgmPlaybackPort.prepareHandler = { [weak self] item, generation in
            self?.prepareRuntimeBGM(item, generation: generation)
        }
        ports.bgmPlaybackPort.playHandler = { [weak self] generation in
            self?.playRuntimeBGM(generation: generation)
        }
        ports.bgmPlaybackPort.pauseHandler = { [weak self] generation in
            self?.pauseRuntimeBGM(generation: generation)
        }
        ports.bgmPlaybackPort.stopHandler = { [weak self] fade, generation in
            self?.stopRuntimeBGM(fade: fade, generation: generation)
        }
        ports.bgmPlaybackPort.setVolumeHandler = { [weak self] volume, fade, generation in
            self?.setRuntimeBGMVolume(volume, fade: fade, generation: generation)
        }
        ports.bgmPlaybackPort.seekToBeginningHandler = { [weak self] generation in
            self?.seekRuntimeBGMToBeginning(generation: generation)
        }
        ports.bgmPlaybackPort.seekToProgressHandler = { [weak self] progress, generation in
            self?.seekRuntimeBGM(toProgress: progress, generation: generation)
        }
        ports.bgmPlaybackPort.setPlayModeHandler = { [weak self] playMode, generation in
            self?.setRuntimeBGMPlayMode(playMode, generation: generation)
        }
        ports.bgmTimerPort.startHandler = { [weak self] generation in
            self?.startBGMTimer(generation: generation)
        }
        ports.bgmTimerPort.stopHandler = { [weak self] generation in
            self?.stopBGMTimer(generation: generation)
        }
        ports.audioRoutingPort.applyHandler = { [weak self] reason, state in
            self?.applyAudioRoutingForRuntimeChange(reason: reason, runtimeState: state)
        }
        ports.imageAssetPort.loadBackgroundImageHandler = { [weak self] url in
            self?.loadBackgroundImage(from: url)
        }
        ports.imageAssetPort.loadCornerLogoImageHandler = { [weak self] url in
            self?.loadCornerLogoImage(from: url)
        }
        ports.persistencePort.saveHandler = { [weak self] in
            self?.saveData()
        }
        ports.persistencePort.saveConsoleModeHandler = { [weak self] mode in
            self?.persistConsoleModeFromRuntime(mode)
        }
        ports.persistencePort.saveThemeOverrideHandler = { [weak self] theme in
            self?.persistThemeOverrideFromRuntime(theme)
        }
        ports.persistencePort.saveAudioStrategyHandler = { [weak self] strategy in
            self?.persistAudioStrategyFromRuntime(strategy)
        }
        ports.persistencePort.saveSpeakerModeHandler = { [weak self] isEnabled in
            self?.persistSpeakerModeFromRuntime(isEnabled)
        }
        ports.persistencePort.saveBGMPlayModeHandler = { [weak self] playMode in
            self?.persistBGMPlayModeFromRuntime(playMode)
        }
        ports.persistencePort.saveAutoPlayNextVideoOnEndHandler = { [weak self] isEnabled in
            self?.persistAutoPlayNextVideoOnEndFromRuntime(isEnabled)
        }
        ports.persistencePort.saveAutoAdvanceAtScheduledTimeHandler = { [weak self] isEnabled in
            self?.persistAutoAdvanceAtScheduledTimeFromRuntime(isEnabled)
        }
        ports.persistencePort.saveShowAgendaTimelineHandler = { [weak self] isEnabled in
            self?.persistShowAgendaTimelineFromRuntime(isEnabled)
        }
        ports.persistencePort.saveCornerLogoPositionHandler = { [weak self] position in
            self?.persistCornerLogoPositionFromRuntime(position)
        }
    }
}
