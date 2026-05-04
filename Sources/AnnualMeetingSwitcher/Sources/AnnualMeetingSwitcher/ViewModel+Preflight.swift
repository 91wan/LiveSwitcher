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
            wallpaperCount: backgroundWallpapers.count,
            autoPlayNextVideoOnEnd: autoPlayNextVideoOnEnd,
            effectiveMediaVolume: effectiveMediaOutputVolume(),
            effectiveBGMVolume: effectiveBGMOutputVolume()
        )
    }

    var livePreflightChecks: [LivePreflightCheck] {
        LivePreflightCheck.build(from: livePreflightSnapshot)
    }

    func livePreflightReportText() -> String {
        let snapshot = livePreflightSnapshot
        return LivePreflightReport.makePlainText(
            snapshot: snapshot,
            checks: LivePreflightCheck.build(from: snapshot)
        )
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
