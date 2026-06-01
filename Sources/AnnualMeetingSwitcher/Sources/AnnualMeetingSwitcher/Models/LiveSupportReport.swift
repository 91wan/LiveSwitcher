import Foundation

enum LiveSupportEventKind: String, Equatable {
    case preflightAction = "preflight.action"
    case supportReportCopied = "support.report.copied"
    case supportReportSaved = "support.report.saved"
    case speakerModeChanged = "speaker.mode.changed"
    case pptModeChanged = "ppt.mode.changed"
    case panicModeChanged = "panic.mode.changed"
    case fadeToBlackChanged = "fade-to-black.changed"
    case bgmPlaybackChanged = "bgm.playback.changed"
    case bgmTakeoverChanged = "bgm.takeover.changed"
    case bgmPlaybackFailed = "bgm.playback.failed"
    case bgmImportSkippedDuplicate = "bgm.import.duplicate"
    case projectionToggle = "projection.toggle"
    case projectionFailClosed = "projection.fail.closed"
    case projectionStarted = "projection.started"
    case projectionStopped = "projection.stopped"
    case projectionStartFailed = "projection.start.failed"
    case projectionLost = "projection.lost"
    case pageInterceptEnabled = "page.intercept.enabled"
    case pageInterceptDisabled = "page.intercept.disabled"
    case pageInterceptForwardedToWPS = "page.intercept.forwarded-to-wps"
    case pageInterceptWPSNotRunning = "page.intercept.wps-not-running"
    case pageInterceptAutoReenabled = "page.intercept.auto-reenabled"
    case systemVolumeSynced = "system.volume.synced"
    case playbackReachedEnd = "playback.reached-end"
    case mediaRestarted = "media.restarted"
    case consoleModeSwitchSlow = "console-mode.switch.slow"
    case programItemFileMissing = "program.file.missing"
    case bgmFileMissing = "bgm.file.missing"
    case wallpaperFileMissing = "wallpaper.file.missing"
    case appleScriptFailed = "applescript.failed"
    case countdownStarted = "overlay.countdown.started"
    case countdownStopped = "overlay.countdown.stopped"
    case tickerStarted = "overlay.ticker.started"
    case tickerStopped = "overlay.ticker.stopped"
    case lowerThirdShown = "overlay.lower-third.shown"
    case lowerThirdHidden = "overlay.lower-third.hidden"
    case overlaysCleared = "overlay.clear-all"
}

struct LiveSupportEvent: Equatable {
    var timestamp: Date
    var kind: LiveSupportEventKind
    var detail: String

    init(timestamp: Date, kind: LiveSupportEventKind, detail: String) {
        self.timestamp = timestamp
        self.kind = kind
        self.detail = LiveSupportRedactor.safeEventDetail(detail)
    }
}

enum LiveSupportReport {
    static func makePlainText(
        snapshot: LiveDiagnosticsSnapshot,
        checks: [LivePreflightCheck],
        events: [LiveSupportEvent],
        actionLog: [LiveRuntimeActionLogEntry] = [],
        generatedAt: Date = Date()
    ) -> String {
        let safePreflight = supportSafeSnapshot(snapshot.preflight)
        let safeDiagnostics = LiveDiagnosticsSnapshot(
            appVersion: snapshot.appVersion,
            operatingSystem: snapshot.operatingSystem,
            architecture: snapshot.architecture,
            preflight: safePreflight
        )
        let safeChecks = checks.map(supportSafeCheck)
        let diagnostics = LiveDiagnosticsReport.makePlainText(snapshot: safeDiagnostics, checks: safeChecks)
        let preflight = LivePreflightReport.makePlainText(snapshot: safePreflight, checks: safeChecks)

        var lines: [String] = [
            "LiveSwitcher Support Report v\(snapshot.appVersion)",
            "Generated: \(isoString(generatedAt))",
            "",
            "[Privacy Notice]",
            "Text-only sanitized report. It excludes screenshots, system logs, local file paths, raw media filenames, customer content, overlay text, and file URLs.",
            "",
            "[Diagnostics]",
            diagnostics,
            "",
            "[Preflight Report]",
            preflight,
            "",
            "[Recent Events]"
        ]

        if events.isEmpty {
            lines.append("- No recent support events.")
        } else {
            lines.append(contentsOf: events.map { event in
                "- \(isoString(event.timestamp)) \(event.kind.rawValue): \(event.detail)"
            })
        }

        lines += [
            "",
            "[Recent Runtime Actions]"
        ]
        if actionLog.isEmpty {
            lines.append("- No recent runtime actions.")
        } else {
            lines.append(contentsOf: actionLog.suffix(40).map { entry in
                "- \(isoString(entry.timestamp)) \(entry.actionName): \(entry.oldStateSummary) -> \(entry.newStateSummary)"
            })
        }

        return LiveSupportRedactor.safeText(lines.joined(separator: "\n"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func supportSafeSnapshot(_ snapshot: LivePreflightSnapshot) -> LivePreflightSnapshot {
        var safeSnapshot = snapshot
        if safeSnapshot.currentProgramTitle != nil {
            safeSnapshot.currentProgramTitle = "Selected program"
        }
        return safeSnapshot
    }

    private static func supportSafeCheck(_ check: LivePreflightCheck) -> LivePreflightCheck {
        LivePreflightCheck(
            id: LiveSupportRedactor.safeText(check.id),
            group: check.group,
            status: check.status,
            title: LiveSupportRedactor.safeText(check.title),
            message: LiveSupportRedactor.safeText(check.message),
            actionLabel: check.actionLabel.map(LiveSupportRedactor.safeText),
            actionKind: check.actionKind
        )
    }

    private static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}

enum LiveSupportRedactor {
    static func safeText(_ text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map(safeLine)
            .joined(separator: "\n")
    }

    static func safeEventDetail(_ text: String) -> String {
        safeText(text)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func safeLine(_ text: String) -> String {
        redactSensitiveMarkerTokens(in:
            redactFilenameTokens(in:
                redactPathTokens(in: text)
            )
        )
    }

    private static func redactPathTokens(in text: String) -> String {
        let extensionPattern = protectedExtensionPattern
        let pathRootPattern = #"~|/Users|/Volumes|/private|/tmp|/Applications|/var/folders"#
        let fileURLPattern = #"(?i)file://[^\s,;)\]}]+"#
        let pathWithExtensionPattern = #"(?i)(?:\#(pathRootPattern))/[^,\n;)\]}]*?\.(?:\#(extensionPattern))\b"#
        let fallbackPathPattern = #"(?i)(?:\#(pathRootPattern))/[^\s,;)\]}]+"#

        return replaceMatches(
            in: replaceMatches(
                in: replaceMatches(in: text, pattern: fileURLPattern, with: "[path redacted]"),
                pattern: pathWithExtensionPattern,
                with: "[path redacted]"
            ),
            pattern: fallbackPathPattern,
            with: "[path redacted]"
        )
    }

    private static func redactFilenameTokens(in text: String) -> String {
        let quotedPattern = #"(?i)["'\u{201C}\u{2018}][^"'\u{201D}\u{2019}\n/\\:]+?\.(?:\#(protectedExtensionPattern))["'\u{201D}\u{2019}]"#
        let filenamePattern = #"(?i)(?<![A-Za-z0-9_/\\.-])[\p{L}\p{N}][\p{L}\p{N} _.-]{0,120}?\.(?:\#(protectedExtensionPattern))\b"#

        return replaceMatches(
            in: replaceMatches(in: text, pattern: quotedPattern, with: "[filename redacted]"),
            pattern: filenamePattern,
            with: "[filename redacted]"
        )
    }

    private static func redactSensitiveMarkerTokens(in text: String) -> String {
        text
            .replacingOccurrences(of: "ditu" + "liveswitcher", with: "[identifier redacted]", options: .caseInsensitive)
            .replacingOccurrences(of: "com." + "didu", with: "[identifier redacted]", options: .caseInsensitive)
    }

    private static var protectedExtensionPattern: String {
        [
            "mov", "mp4", "m4v", "avi",
            "mp3", "m4a", "wav", "aac", "flac",
            "key", "ppt", "pptx",
            "html", "htm",
            "png", "jpg", "jpeg", "gif", "heic", "webp", "tiff", "bmp",
            "zip"
        ].joined(separator: "|")
    }

    private static func replaceMatches(in text: String, pattern: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: template
        )
    }
}
