import Foundation

extension SwitcherViewModel {
    var livePreflightSnapshot: LivePreflightSnapshot {
        let currentSource = currentProgramItem.map { item in
            item.sourceKind.preflightLabel
        }
        let overlayCount = [
            isCountdownActive,
            isTickerActive,
            isLowerThirdVisible
        ].filter { $0 }.count
        let overlayKinds: [LiveOverlayKind] = [
            isCountdownActive ? .countdown : nil,
            isTickerActive ? .ticker : nil,
            isLowerThirdVisible ? .lowerThird : nil
        ].compactMap { $0 }

        return LivePreflightSnapshot(
            appVersion: AppConfiguration.appVersion,
            hasExternalDisplay: externalScreenProvider() != nil,
            isBroadcasting: isBroadcasting,
            broadcastSafetyNotice: broadcastSafetyNotice,
            programItemCount: programItems.count,
            currentProgramTitle: currentProgramItem?.title,
            currentProgramSource: currentSource,
            bgmItemCount: bgmItems.count,
            isBGMPlaying: isBGMPlaying,
            isBGMAudioTakeoverActive: isBGMAudioTakeoverActive,
            isSpeakerMode: isSpeakerMode,
            isPanicMode: isPanicMode,
            isPageInterceptEnabled: isPageInterceptEnabled,
            activeOverlayCount: overlayCount,
            activeOverlayKinds: overlayKinds,
            countdownRemainingSeconds: isCountdownActive ? countdownSeconds : nil,
            wallpaperCount: backgroundWallpapers.count,
            autoPlayNextVideoOnEnd: autoPlayNextVideoOnEnd,
            effectiveMediaVolume: effectiveMediaOutputVolume(),
            effectiveBGMVolume: effectiveBGMOutputVolume()
        )
    }

    var livePreflightChecks: [LivePreflightCheck] {
        LivePreflightCheck.build(from: livePreflightSnapshot)
    }

    var livePreflightSummary: LivePreflightSummary {
        LivePreflightSummary.make(from: livePreflightChecks)
    }

    func livePreflightReportText() -> String {
        let snapshot = livePreflightSnapshot
        return LivePreflightReport.makePlainText(
            snapshot: snapshot,
            checks: LivePreflightCheck.build(from: snapshot)
        )
    }

    var liveDiagnosticsSnapshot: LiveDiagnosticsSnapshot {
        LiveDiagnosticsSnapshot.make(preflight: livePreflightSnapshot)
    }

    func liveDiagnosticsReportText() -> String {
        let snapshot = liveDiagnosticsSnapshot
        return LiveDiagnosticsReport.makePlainText(
            snapshot: snapshot,
            checks: LivePreflightCheck.build(from: snapshot.preflight)
        )
    }

    func liveSupportReportText(generatedAt: Date = Date()) -> String {
        let snapshot = liveDiagnosticsSnapshot
        return LiveSupportReport.makePlainText(
            snapshot: snapshot,
            checks: LivePreflightCheck.build(from: snapshot.preflight),
            events: supportEvents,
            generatedAt: generatedAt
        )
    }

    @discardableResult
    func performLivePreflightAction(_ action: LivePreflightActionKind) -> Bool {
        let didMutate: Bool
        switch action {
        case .clearOverlays:
            clearAllOverlays()
            didMutate = true
        case .turnOffPanic:
            if isPanicMode {
                togglePanicMode()
                didMutate = true
            } else {
                didMutate = false
            }
        case .openPreview, .openAudioMixer, .openOverlays, .needsHardware, .manualReview:
            didMutate = false
        }
        LiveSwitcherTelemetry.preflightAction(action, didMutateState: didMutate)
        recordSupportEvent(
            kind: .preflightAction,
            detail: "\(action.rawValue), mutated=\(didMutate)"
        )
        return didMutate
    }
}

private extension ProgramSourceKind {
    var preflightLabel: String {
        switch self {
        case .media:
            return "Media"
        case .html:
            return "HTML"
        case .keynote:
            return "Keynote"
        case .pptx:
            return "PPTX"
        case .activeDeck:
            return "Active Keynote Deck"
        case .unsupported:
            return "Unsupported"
        }
    }
}
