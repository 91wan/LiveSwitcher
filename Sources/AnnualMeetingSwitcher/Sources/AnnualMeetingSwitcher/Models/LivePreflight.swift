import Foundation

enum LivePreflightGroup: String, CaseIterable {
    case display = "Display"
    case audio = "Audio"
    case playback = "Playback"
    case overlays = "Overlays"
    case controls = "Controls"

    var displayTitle: String {
        switch self {
        case .display:
            return "Display / 显示"
        case .audio:
            return "Audio / 音频"
        case .playback:
            return "Playback / 播放"
        case .overlays:
            return "Overlays / 叠层"
        case .controls:
            return "Controls / 控制"
        }
    }
}

enum LivePreflightStatus: String {
    case pass = "PASS"
    case warn = "WARN"
    case fail = "FAIL"

    var displayTitle: String {
        switch self {
        case .pass:
            return "Pass"
        case .warn:
            return "Warn"
        case .fail:
            return "Fail"
        }
    }
}

enum LivePreflightActionPresentationRole: Equatable {
    case safeOneClick
    case navigation
    case operatorGuidance
}

enum LivePreflightActionKind: String, Equatable {
    case clearOverlays
    case turnOffPanic
    case openPreview
    case openAudioMixer
    case openOverlays
    case needsHardware
    case manualReview

    var presentationRole: LivePreflightActionPresentationRole {
        switch self {
        case .clearOverlays, .turnOffPanic:
            return .safeOneClick
        case .openPreview, .openAudioMixer, .openOverlays:
            return .navigation
        case .needsHardware, .manualReview:
            return .operatorGuidance
        }
    }

    var shouldRenderAsButton: Bool {
        presentationRole != .operatorGuidance
    }

    var isEnabledInPreflightUI: Bool {
        shouldRenderAsButton
    }
}

struct LivePreflightSnapshot: Equatable {
    var appVersion: String
    var hasExternalDisplay: Bool
    var isBroadcasting: Bool
    var broadcastSafetyNotice: String?
    var programItemCount: Int
    var currentProgramTitle: String?
    var currentProgramSource: String?
    var bgmItemCount: Int
    var isBGMPlaying: Bool
    var isBGMAudioTakeoverActive: Bool
    var isSpeakerMode: Bool
    var isPanicMode: Bool
    var isPageInterceptEnabled: Bool
    var activeOverlayCount: Int
    var wallpaperCount: Int
    var autoPlayNextVideoOnEnd: Bool
    var effectiveMediaVolume: Float
    var effectiveBGMVolume: Float
}

struct LivePreflightCheck: Identifiable, Equatable {
    let id: String
    let group: LivePreflightGroup
    let status: LivePreflightStatus
    let title: String
    let message: String
    let actionLabel: String?
    let actionKind: LivePreflightActionKind?

    init(
        id: String,
        group: LivePreflightGroup,
        status: LivePreflightStatus,
        title: String,
        message: String,
        actionLabel: String? = nil,
        actionKind: LivePreflightActionKind? = nil
    ) {
        self.id = id
        self.group = group
        self.status = status
        self.title = title
        self.message = message
        self.actionLabel = actionLabel
        self.actionKind = actionKind
    }

    static func build(from snapshot: LivePreflightSnapshot) -> [LivePreflightCheck] {
        [
            displayCheck(snapshot),
            broadcastCheck(snapshot),
            bgmLibraryCheck(snapshot),
            speakerModeCheck(snapshot),
            bgmTakeoverCheck(snapshot),
            volumeCheck(snapshot),
            currentProgramCheck(snapshot),
            wallpaperCheck(snapshot),
            autoNextCheck(snapshot),
            overlayCheck(snapshot),
            panicCheck(snapshot),
            pptCheck(snapshot)
        ]
    }

    static func attentionChecks(from checks: [LivePreflightCheck]) -> [LivePreflightCheck] {
        checks.filter { $0.status != .pass }
    }

    private static func displayCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        if snapshot.hasExternalDisplay {
            return LivePreflightCheck(
                id: "display.external",
                group: .display,
                status: .pass,
                title: "External Display",
                message: "External display detected. Projection can be armed."
            )
        }

        return LivePreflightCheck(
            id: "display.external",
            group: .display,
            status: .fail,
            title: "External Display",
            message: "Needs hardware: no external display detected. Do not project.",
            actionLabel: "Needs hardware",
            actionKind: .needsHardware
        )
    }

    private static func broadcastCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        if snapshot.isBroadcasting && !snapshot.hasExternalDisplay {
            return LivePreflightCheck(
                id: "display.broadcast",
                group: .display,
                status: .fail,
                title: "Projection State",
                message: "Projection reports active without an external display. Stop projection before the show.",
                actionLabel: "Needs hardware",
                actionKind: .needsHardware
            )
        }

        if snapshot.isBroadcasting {
            return LivePreflightCheck(
                id: "display.broadcast",
                group: .display,
                status: .pass,
                title: "Projection State",
                message: "Projection is currently active on an external display."
            )
        }

        if let notice = snapshot.broadcastSafetyNotice, !notice.isEmpty {
            return LivePreflightCheck(
                id: "display.broadcast",
                group: .display,
                status: .warn,
                title: "Projection State",
                message: "Projection is off. Last notice: \(notice)",
                actionLabel: "Open preview",
                actionKind: .openPreview
            )
        }

        return LivePreflightCheck(
            id: "display.broadcast",
            group: .display,
            status: .warn,
            title: "Projection State",
            message: "Projection is off. Confirm the external display before going live.",
            actionLabel: "Open preview",
            actionKind: .openPreview
        )
    }

    private static func bgmLibraryCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        guard snapshot.bgmItemCount > 0 else {
            return LivePreflightCheck(
                id: "audio.bgm-library",
                group: .audio,
                status: .warn,
                title: "BGM Library",
                message: "No BGM tracks loaded. Add walk-in or fallback music before a live run.",
                actionLabel: "Open audio mixer",
                actionKind: .openAudioMixer
            )
        }

        return LivePreflightCheck(
            id: "audio.bgm-library",
            group: .audio,
            status: .pass,
            title: "BGM Library",
            message: "\(snapshot.bgmItemCount) BGM track(s) loaded."
        )
    }

    private static func speakerModeCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        if snapshot.isSpeakerMode {
            return LivePreflightCheck(
                id: "audio.speaker",
                group: .audio,
                status: .warn,
                title: "Speaker Mode",
                message: "Media and BGM ducking is active. Confirm this is intentional before playback."
            )
        }

        return LivePreflightCheck(
            id: "audio.speaker",
            group: .audio,
            status: .pass,
            title: "Speaker Mode",
            message: "Speaker mode is off. Media and BGM use the current mixer levels."
        )
    }

    private static func bgmTakeoverCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        if snapshot.isBGMAudioTakeoverActive {
            return LivePreflightCheck(
                id: "audio.bgm-takeover",
                group: .audio,
                status: .warn,
                title: "BGM Takeover",
                message: "Media audio is muted by BGM takeover while BGM plays.",
                actionLabel: "Open audio mixer",
                actionKind: .openAudioMixer
            )
        }

        return LivePreflightCheck(
            id: "audio.bgm-takeover",
            group: .audio,
            status: .pass,
            title: "BGM Takeover",
            message: snapshot.isBGMPlaying
                ? "BGM is playing without takeover."
                : "BGM takeover is inactive."
        )
    }

    private static func volumeCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        LivePreflightCheck(
            id: "audio.volumes",
            group: .audio,
            status: .pass,
            title: "Effective Volumes",
            message: "Media \(formatPercent(snapshot.effectiveMediaVolume)), BGM \(formatPercent(snapshot.effectiveBGMVolume))."
        )
    }

    private static func currentProgramCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        if let title = snapshot.currentProgramTitle, let source = snapshot.currentProgramSource {
            return LivePreflightCheck(
                id: "playback.current-program",
                group: .playback,
                status: .pass,
                title: "Current Program",
                message: "\(safeReportText(title)) is selected as \(source)."
            )
        }

        if snapshot.programItemCount > 0 {
            return LivePreflightCheck(
                id: "playback.current-program",
                group: .playback,
                status: .warn,
                title: "Current Program",
                message: "\(snapshot.programItemCount) program item(s) queued, but no current program is selected.",
                actionLabel: "Open preview",
                actionKind: .openPreview
            )
        }

        return LivePreflightCheck(
            id: "playback.current-program",
            group: .playback,
            status: .warn,
            title: "Current Program",
            message: "No program items loaded.",
            actionLabel: "Open preview",
            actionKind: .openPreview
        )
    }

    private static func wallpaperCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        guard snapshot.wallpaperCount > 0 else {
            return LivePreflightCheck(
                id: "playback.wallpaper",
                group: .playback,
                status: .warn,
                title: "Wallpaper Fallback",
                message: "No wallpaper fallback is loaded. Add at least one neutral standby image.",
                actionLabel: "Open preview",
                actionKind: .openPreview
            )
        }

        return LivePreflightCheck(
            id: "playback.wallpaper",
            group: .playback,
            status: .pass,
            title: "Wallpaper Fallback",
            message: "\(snapshot.wallpaperCount) wallpaper fallback image(s) available."
        )
    }

    private static func autoNextCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        LivePreflightCheck(
            id: "playback.auto-next",
            group: .playback,
            status: snapshot.autoPlayNextVideoOnEnd ? .warn : .pass,
            title: "Auto-next Video",
            message: snapshot.autoPlayNextVideoOnEnd
                ? "Auto-next video is enabled. Verify the next video order before the show."
                : "Auto-next video is off. Video end will return to standby/fallback.",
            actionLabel: snapshot.autoPlayNextVideoOnEnd ? "Open preview" : nil,
            actionKind: snapshot.autoPlayNextVideoOnEnd ? .openPreview : nil
        )
    }

    private static func overlayCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        if snapshot.activeOverlayCount > 0 {
            return LivePreflightCheck(
                id: "overlays.active",
                group: .overlays,
                status: .warn,
                title: "Active Overlays",
                message: "\(snapshot.activeOverlayCount) overlays active. Clear overlays if the stage should start clean.",
                actionLabel: "Clear overlays",
                actionKind: .clearOverlays
            )
        }

        return LivePreflightCheck(
            id: "overlays.active",
            group: .overlays,
            status: .pass,
            title: "Active Overlays",
            message: "No overlays are currently live."
        )
    }

    private static func panicCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        if snapshot.isPanicMode {
            return LivePreflightCheck(
                id: "controls.panic",
                group: .controls,
                status: .fail,
                title: "Panic Blackout",
                message: "Panic blackout is active. Output is blacked out and audio is muted.",
                actionLabel: "Turn off panic",
                actionKind: .turnOffPanic
            )
        }

        return LivePreflightCheck(
            id: "controls.panic",
            group: .controls,
            status: .pass,
            title: "Panic Blackout",
            message: "Panic blackout is off."
        )
    }

    private static func pptCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        LivePreflightCheck(
            id: "controls.ppt",
            group: .controls,
            status: .pass,
            title: "PPT Mode",
            message: snapshot.isPageInterceptEnabled
                ? "PPT mode is on. Page-clicker keys are intercepted for presentation control."
                : "PPT mode is off. Enable it only when page-clicker takeover is needed.",
            actionLabel: "Manual review",
            actionKind: .manualReview
        )
    }

    private static func formatPercent(_ volume: Float) -> String {
        "\(Int((max(0, min(volume, 1)) * 100).rounded()))%"
    }

    static func safeReportText(_ text: String) -> String {
        let components = text.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count > 2 else { return text }
        return "[local path redacted]"
    }
}

struct LivePreflightSummary: Equatable {
    let status: LivePreflightStatus
    let title: String
    let message: String
    let passCount: Int
    let warnCount: Int
    let failCount: Int

    static func make(from checks: [LivePreflightCheck]) -> LivePreflightSummary {
        let passCount = checks.filter { $0.status == .pass }.count
        let warnCount = checks.filter { $0.status == .warn }.count
        let failCount = checks.filter { $0.status == .fail }.count

        if failCount > 0 {
            return LivePreflightSummary(
                status: .fail,
                title: "Not ready",
                message: "\(failCount) blocking issue(s). Resolve fail rows before projection.",
                passCount: passCount,
                warnCount: warnCount,
                failCount: failCount
            )
        }

        if warnCount > 0 {
            return LivePreflightSummary(
                status: .warn,
                title: "Needs review",
                message: "\(warnCount) warning(s). Confirm the intended show state before going live.",
                passCount: passCount,
                warnCount: warnCount,
                failCount: failCount
            )
        }

        return LivePreflightSummary(
            status: .pass,
            title: "Ready",
            message: "All preflight checks are passing for the current runtime state.",
            passCount: passCount,
            warnCount: warnCount,
            failCount: failCount
        )
    }
}

enum LivePreflightReport {
    static func makePlainText(snapshot: LivePreflightSnapshot, checks: [LivePreflightCheck]) -> String {
        let summary = LivePreflightSummary.make(from: checks)
        var lines: [String] = [
            "LiveSwitcher Preflight v\(snapshot.appVersion)",
            "Overall: \(summary.status.rawValue) - \(summary.title) (\(summary.passCount) pass, \(summary.warnCount) warn, \(summary.failCount) fail)",
            "External display: \(snapshot.hasExternalDisplay ? "detected" : "not detected")",
            "Projection: \(snapshot.isBroadcasting ? "on" : "off")",
            "Effective volumes: media \(formatPercent(snapshot.effectiveMediaVolume)), BGM \(formatPercent(snapshot.effectiveBGMVolume))",
            ""
        ]

        for group in LivePreflightGroup.allCases {
            let groupedChecks = checks.filter { $0.group == group }
            guard !groupedChecks.isEmpty else { continue }
            lines.append("[\(group.rawValue)]")
            lines.append(contentsOf: groupedChecks.map { check in
                let actionText = check.actionLabel.map { " Action: \($0)." } ?? ""
                return "- \(check.status.rawValue) \(check.title): \(LivePreflightCheck.safeReportText(check.message))\(actionText)"
            })
            lines.append("")
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func formatPercent(_ volume: Float) -> String {
        "\(Int((max(0, min(volume, 1)) * 100).rounded()))%"
    }
}
