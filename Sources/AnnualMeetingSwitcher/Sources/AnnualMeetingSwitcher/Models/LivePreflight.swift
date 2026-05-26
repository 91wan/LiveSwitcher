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
            return "显示"
        case .audio:
            return "音频"
        case .playback:
            return "播放"
        case .overlays:
            return "叠层"
        case .controls:
            return "控制"
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
            return "通过"
        case .warn:
            return "警告"
        case .fail:
            return "故障"
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

enum LiveOverlayKind: String, Equatable, CaseIterable {
    case countdown
    case ticker
    case lowerThird

    var displayTitle: String {
        switch self {
        case .countdown:
            return "倒计时"
        case .ticker:
            return "游动字幕"
        case .lowerThird:
            return "人名条"
        }
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
    var currentProgramScheduledStartAt: Date? = nil
    var currentProgramScheduledDuration: TimeInterval? = nil
    var currentProgramSwitchedAt: Date? = nil
    var scheduleNow: Date = Date()
    var bgmItemCount: Int
    var isBGMPlaying: Bool
    var isBGMAudioTakeoverActive: Bool
    var isSpeakerMode: Bool
    var isPanicMode: Bool
    var isPageInterceptEnabled: Bool
    var activeOverlayCount: Int
    var activeOverlayKinds: [LiveOverlayKind] = []
    var countdownRemainingSeconds: Int? = nil
    var wallpaperCount: Int
    var autoPlayNextVideoOnEnd: Bool
    var effectiveMediaVolume: Float
    var effectiveBGMVolume: Float

    static func == (lhs: LivePreflightSnapshot, rhs: LivePreflightSnapshot) -> Bool {
        lhs.appVersion == rhs.appVersion &&
        lhs.hasExternalDisplay == rhs.hasExternalDisplay &&
        lhs.isBroadcasting == rhs.isBroadcasting &&
        lhs.broadcastSafetyNotice == rhs.broadcastSafetyNotice &&
        lhs.programItemCount == rhs.programItemCount &&
        lhs.currentProgramTitle == rhs.currentProgramTitle &&
        lhs.currentProgramSource == rhs.currentProgramSource &&
        lhs.currentProgramScheduledStartAt == rhs.currentProgramScheduledStartAt &&
        lhs.currentProgramScheduledDuration == rhs.currentProgramScheduledDuration &&
        lhs.currentProgramSwitchedAt == rhs.currentProgramSwitchedAt &&
        lhs.bgmItemCount == rhs.bgmItemCount &&
        lhs.isBGMPlaying == rhs.isBGMPlaying &&
        lhs.isBGMAudioTakeoverActive == rhs.isBGMAudioTakeoverActive &&
        lhs.isSpeakerMode == rhs.isSpeakerMode &&
        lhs.isPanicMode == rhs.isPanicMode &&
        lhs.isPageInterceptEnabled == rhs.isPageInterceptEnabled &&
        lhs.activeOverlayCount == rhs.activeOverlayCount &&
        lhs.activeOverlayKinds == rhs.activeOverlayKinds &&
        lhs.countdownRemainingSeconds == rhs.countdownRemainingSeconds &&
        lhs.wallpaperCount == rhs.wallpaperCount &&
        lhs.autoPlayNextVideoOnEnd == rhs.autoPlayNextVideoOnEnd &&
        lhs.effectiveMediaVolume == rhs.effectiveMediaVolume &&
        lhs.effectiveBGMVolume == rhs.effectiveBGMVolume
    }
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
                title: "外接显示器",
                message: "已检测到外接显示器，可以准备投射。"
            )
        }

        return LivePreflightCheck(
            id: "display.external",
            group: .display,
            status: .fail,
            title: "外接显示器",
            message: "需要硬件：未检测到外接显示器，请勿投射。",
            actionLabel: "需要硬件",
            actionKind: .needsHardware
        )
    }

    private static func broadcastCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        if snapshot.isBroadcasting && !snapshot.hasExternalDisplay {
            return LivePreflightCheck(
                id: "display.broadcast",
                group: .display,
                status: .fail,
                title: "投射状态",
                message: "投射状态为开启，但未检测到外接显示器。开场前请停止投射。",
                actionLabel: "需要硬件",
                actionKind: .needsHardware
            )
        }

        if snapshot.isBroadcasting {
            return LivePreflightCheck(
                id: "display.broadcast",
                group: .display,
                status: .pass,
                title: "投射状态",
                message: "当前正在外接屏投射。"
            )
        }

        if let notice = snapshot.broadcastSafetyNotice, !notice.isEmpty {
            return LivePreflightCheck(
                id: "display.broadcast",
                group: .display,
                status: .warn,
                title: "投射状态",
                message: "投射未开启。最近提示：\(notice)",
                actionLabel: "打开节目单",
                actionKind: .openPreview
            )
        }

        return LivePreflightCheck(
            id: "display.broadcast",
            group: .display,
            status: .warn,
            title: "投射状态",
            message: "投射未开启。直播前请确认外接屏。",
            actionLabel: "打开节目单",
            actionKind: .openPreview
        )
    }

    private static func bgmLibraryCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        guard snapshot.bgmItemCount > 0 else {
            return LivePreflightCheck(
                id: "audio.bgm-library",
                group: .audio,
                status: .warn,
                title: "BGM 库",
                message: "未载入 BGM 曲目。直播前请添加暖场或备用音乐。",
                actionLabel: "打开音频页",
                actionKind: .openAudioMixer
            )
        }

        return LivePreflightCheck(
            id: "audio.bgm-library",
            group: .audio,
            status: .pass,
            title: "BGM 库",
            message: "已载入 \(snapshot.bgmItemCount) 首 BGM。"
        )
    }

    private static func speakerModeCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        if snapshot.isSpeakerMode {
            return LivePreflightCheck(
                id: "audio.speaker",
                group: .audio,
                status: .warn,
                title: "主持人模式",
                message: "媒体和 BGM 压低已开启。播放前请确认这是预期状态。"
            )
        }

        return LivePreflightCheck(
            id: "audio.speaker",
            group: .audio,
            status: .pass,
            title: "主持人模式",
            message: "主持人模式关闭。媒体和 BGM 使用当前调音台电平。"
        )
    }

    private static func bgmTakeoverCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        if snapshot.isBGMAudioTakeoverActive {
            return LivePreflightCheck(
                id: "audio.bgm-takeover",
                group: .audio,
                status: .warn,
                title: "BGM 接管",
                message: "BGM 播放时媒体声道被 BGM 接管静音。",
                actionLabel: "打开音频页",
                actionKind: .openAudioMixer
            )
        }

        return LivePreflightCheck(
            id: "audio.bgm-takeover",
            group: .audio,
            status: .pass,
            title: "BGM 接管",
            message: snapshot.isBGMPlaying
                ? "BGM 正在播放，但未接管媒体声道。"
                : "BGM 接管未开启。"
        )
    }

    private static func volumeCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        return LivePreflightCheck(
            id: "audio.volumes",
            group: .audio,
            status: .pass,
            title: "实际音量",
            message: "媒体 \(formatPercent(snapshot.effectiveMediaVolume))，BGM \(formatPercent(snapshot.effectiveBGMVolume))。"
        )
    }

    private static func currentProgramCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        if let title = snapshot.currentProgramTitle, let source = snapshot.currentProgramSource {
            return LivePreflightCheck(
                id: "playback.current-program",
                group: .playback,
                status: .pass,
                title: "当前节目",
                message: "\(safeReportText(title)) 已选为 \(source)。"
            )
        }

        if snapshot.programItemCount > 0 {
            return LivePreflightCheck(
                id: "playback.current-program",
                group: .playback,
                status: .warn,
                title: "当前节目",
                message: "队列中有 \(snapshot.programItemCount) 个节目，但尚未选择当前节目。",
                actionLabel: "打开节目单",
                actionKind: .openPreview
            )
        }

        return LivePreflightCheck(
            id: "playback.current-program",
            group: .playback,
            status: .warn,
            title: "当前节目",
            message: "尚未载入节目。",
            actionLabel: "打开节目单",
            actionKind: .openPreview
        )
    }

    private static func wallpaperCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        guard snapshot.wallpaperCount > 0 else {
            return LivePreflightCheck(
                id: "playback.wallpaper",
                group: .playback,
                status: .warn,
                title: "待机壁纸",
                message: "尚未载入待机壁纸。请至少添加一张中性背景图。",
                actionLabel: "打开节目单",
                actionKind: .openPreview
            )
        }

        return LivePreflightCheck(
            id: "playback.wallpaper",
            group: .playback,
            status: .pass,
            title: "待机壁纸",
            message: "已有 \(snapshot.wallpaperCount) 张待机壁纸可用。"
        )
    }

    private static func autoNextCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        return LivePreflightCheck(
            id: "playback.auto-next",
            group: .playback,
            status: snapshot.autoPlayNextVideoOnEnd ? .warn : .pass,
            title: "自动下一条视频",
            message: snapshot.autoPlayNextVideoOnEnd
                ? "自动下一条视频已开启。开场前请确认下一条视频顺序。"
                : "自动下一条视频关闭。视频结束后会回到待机/备用画面。",
            actionLabel: snapshot.autoPlayNextVideoOnEnd ? "打开节目单" : nil,
            actionKind: snapshot.autoPlayNextVideoOnEnd ? .openPreview : nil
        )
    }

    private static func overlayCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        if snapshot.activeOverlayCount > 0 {
            let overlaySummary = overlaySummary(snapshot)
            return LivePreflightCheck(
                id: "overlays.active",
                group: .overlays,
                status: .warn,
                title: "已上屏叠层",
                message: "\(snapshot.activeOverlayCount) 个叠层正在上屏：\(overlaySummary)。如果开场需要干净画面，请先清空叠层。",
                actionLabel: "清空叠层",
                actionKind: .clearOverlays
            )
        }

        return LivePreflightCheck(
            id: "overlays.active",
            group: .overlays,
            status: .pass,
            title: "已上屏叠层",
            message: "当前没有叠层上屏。"
        )
    }

    private static func panicCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        if snapshot.isPanicMode {
            return LivePreflightCheck(
                id: "controls.panic",
                group: .controls,
                status: .fail,
                title: "紧急切黑",
                message: "紧急切黑已开启。副屏黑屏，音频已静音。",
                actionLabel: "关闭紧急切黑",
                actionKind: .turnOffPanic
            )
        }

        return LivePreflightCheck(
            id: "controls.panic",
            group: .controls,
            status: .pass,
            title: "紧急切黑",
            message: "紧急切黑已关闭。"
        )
    }

    private static func pptCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        let source = snapshot.currentProgramSource
        let pageableSources: Set<String> = ["HTML", "Keynote", "PPTX", "Active Keynote Deck"]
        let deckSources: Set<String> = ["Keynote", "PPTX", "Active Keynote Deck"]
        let isPageableSource = source.map { pageableSources.contains($0) } ?? false
        let isDeckSource = source.map { deckSources.contains($0) } ?? false

        let status: LivePreflightStatus
        let message: String
        if snapshot.isPageInterceptEnabled {
            if isPageableSource {
                status = .pass
                message = "PPT 模式已针对可翻页信号源开启。翻页笔按键会用于演示控制。"
            } else {
                status = .warn
                message = "PPT 模式已开启，但当前节目不是可翻页信号源。除非需要接管翻页笔，否则请关闭。"
            }
        } else if isDeckSource {
            status = .warn
            message = "当前载入演示信号源，但 PPT 模式关闭。直播前请确认是否需要接管翻页笔。"
        } else {
            status = .pass
            message = "PPT 模式关闭。仅在需要接管翻页笔时开启。"
        }

        return LivePreflightCheck(
            id: "controls.ppt",
            group: .controls,
            status: status,
            title: "PPT 模式",
            message: message,
            actionLabel: "人工复核",
            actionKind: .manualReview
        )
    }

    private static func formatPercent(_ volume: Float) -> String {
        "\(Int((max(0, min(volume, 1)) * 100).rounded()))%"
    }

    static func overlaySummary(_ snapshot: LivePreflightSnapshot) -> String {
        let kinds = snapshot.activeOverlayKinds.map(\.displayTitle)
        let kindText = kinds.isEmpty ? "未知叠层" : kinds.joined(separator: ", ")
        guard let remaining = snapshot.countdownRemainingSeconds,
              snapshot.activeOverlayKinds.contains(.countdown)
        else {
            return kindText
        }
        return "\(kindText)，剩余 \(remaining)s"
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
                title: "未就绪",
                message: "\(failCount) 个阻塞项。投射前请先解决故障项。",
                passCount: passCount,
                warnCount: warnCount,
                failCount: failCount
            )
        }

        if warnCount > 0 {
            return LivePreflightSummary(
                status: .warn,
                title: "需复核",
                message: "\(warnCount) 个警告。直播前请确认现场状态符合预期。",
                passCount: passCount,
                warnCount: warnCount,
                failCount: failCount
            )
        }

        return LivePreflightSummary(
            status: .pass,
            title: "就绪",
            message: "当前运行状态的现场检查全部通过。",
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
            "Active overlays: \(overlayRuntimeSummary(snapshot))",
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

    private static func overlayRuntimeSummary(_ snapshot: LivePreflightSnapshot) -> String {
        guard snapshot.activeOverlayCount > 0 else { return "none" }
        return "\(snapshot.activeOverlayCount) (\(LivePreflightCheck.overlaySummary(snapshot)))"
    }
}
