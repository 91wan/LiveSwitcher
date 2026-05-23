import Foundation

enum LiveSupportEventKind: String, Equatable {
    case preflightAction = "preflight.action"
    case supportReportCopied = "support.report.copied"
    case supportReportSaved = "support.report.saved"
    case speakerModeChanged = "speaker.mode.changed"
    case panicModeChanged = "panic.mode.changed"
    case bgmTakeoverChanged = "bgm.takeover.changed"
    case projectionToggle = "projection.toggle"
    case projectionStarted = "projection.started"
    case projectionStopped = "projection.stopped"
    case projectionLost = "projection.lost"
    case projectionFailClosed = "projection.fail.closed"
    case countdownStarted = "overlay.countdown.started"
    case countdownStopped = "overlay.countdown.stopped"
    case tickerStarted = "overlay.ticker.started"
    case tickerStopped = "overlay.ticker.stopped"
    case lowerThirdShown = "overlay.lower-third.shown"
    case lowerThirdHidden = "overlay.lower-third.hidden"
    case overlaysCleared = "overlay.cleared"
}

struct LiveSupportEvent: Equatable {
    var timestamp: Date
    var kind: LiveSupportEventKind
    var detail: String

    init(timestamp: Date, kind: LiveSupportEventKind, detail: String) {
        self.timestamp = timestamp
        self.kind = kind
        self.detail = LiveSupportRedactor.safeText(detail)
    }
}

enum LiveSupportReport {
    static func makePlainText(
        snapshot: LiveDiagnosticsSnapshot,
        checks: [LivePreflightCheck],
        events: [LiveSupportEvent],
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

    private static func safeLine(_ text: String) -> String {
        if containsSensitiveLocator(text) {
            return "[sensitive detail redacted]"
        }
        return redactFilenameTokens(in: text)
    }

    private static func containsSensitiveLocator(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return lowered.contains("file://")
            || lowered.contains("/users/")
            || lowered.contains("/volumes/")
            || lowered.contains("/private/")
            || lowered.contains("/tmp/")
            || lowered.contains("ditu" + "liveswitcher")
            || lowered.contains("com." + "didu")
    }

    private static func redactFilenameTokens(in text: String) -> String {
        let pattern = #"(?i)\b[^\s/\\:]+?\.(mov|mp4|m4v|mp3|m4a|wav|aac|flac|key|ppt|pptx)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: "[filename redacted]"
        )
    }
}
