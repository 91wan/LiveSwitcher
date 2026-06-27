import Foundation

extension LivePreflightCheck {
    static func bgmLibraryCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
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

    static func speakerModeCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
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

    static func bgmTakeoverCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
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

    static func volumeCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
        return LivePreflightCheck(
            id: "audio.volumes",
            group: .audio,
            status: .pass,
            title: "实际音量",
            message: "媒体 \(formatPercent(snapshot.effectiveMediaVolume))，BGM \(formatPercent(snapshot.effectiveBGMVolume))。"
        )
    }

    static func currentProgramCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
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

    static func wallpaperCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
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

    static func autoNextCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
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

    static func overlayCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
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

    static func panicCheck(_ snapshot: LivePreflightSnapshot) -> LivePreflightCheck {
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
}
