import Foundation

struct LiveDiagnosticsSnapshot: Equatable {
    var appVersion: String
    var operatingSystem: String
    var architecture: String
    var preflight: LivePreflightSnapshot

    static func make(
        preflight: LivePreflightSnapshot,
        processInfo: ProcessInfo = .processInfo
    ) -> LiveDiagnosticsSnapshot {
        LiveDiagnosticsSnapshot(
            appVersion: preflight.appVersion,
            operatingSystem: processInfo.operatingSystemVersionString,
            architecture: currentArchitecture,
            preflight: preflight
        )
    }

    private static var currentArchitecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}

enum LiveDiagnosticsReport {
    static func makePlainText(snapshot: LiveDiagnosticsSnapshot, checks: [LivePreflightCheck]) -> String {
        let preflight = snapshot.preflight
        let summary = LivePreflightSummary.make(from: checks)

        var lines: [String] = [
            "LiveSwitcher Diagnostics v\(snapshot.appVersion)",
            "Runtime: \(snapshot.operatingSystem), \(snapshot.architecture)",
            "Overall: \(summary.status.rawValue) - \(summary.title) (\(summary.passCount) pass, \(summary.warnCount) warn, \(summary.failCount) fail)",
            "",
            "[Runtime State]",
            "External display: \(preflight.hasExternalDisplay ? "detected" : "not detected")",
            "Projection: \(preflight.isBroadcasting ? "on" : "off")",
            "Current program: \(preflight.currentProgramTitle == nil ? "none" : "selected")",
            "Current source: \(preflight.currentProgramSource ?? "none")",
            "Programs: \(preflight.programItemCount)",
            "BGM tracks: \(preflight.bgmItemCount)",
            "Wallpapers: \(preflight.wallpaperCount)",
            "Active overlays: \(overlayRuntimeSummary(preflight))",
            "Speaker mode: \(preflight.isSpeakerMode ? "on" : "off")",
            "紧急切黑: \(preflight.isPanicMode ? "on" : "off")",
            "PPT mode: \(preflight.isPageInterceptEnabled ? "on" : "off")",
            "BGM playback: \(preflight.isBGMPlaying ? "playing" : "stopped")",
            "BGM takeover: \(preflight.isBGMAudioTakeoverActive ? "active" : "inactive")",
            "Auto-next video: \(preflight.autoPlayNextVideoOnEnd ? "on" : "off")",
            "Effective volumes: media \(formatPercent(preflight.effectiveMediaVolume)), BGM \(formatPercent(preflight.effectiveBGMVolume))",
            ""
        ]

        if let notice = preflight.broadcastSafetyNotice, !notice.isEmpty {
            lines.append("Broadcast safety notice: \(LivePreflightCheck.safeReportText(notice))")
            lines.append("")
        }

        lines.append("[Preflight Checks]")
        for group in LivePreflightGroup.allCases {
            let groupedChecks = checks.filter { $0.group == group }
            guard !groupedChecks.isEmpty else { continue }
            lines.append("\(group.rawValue):")
            lines.append(contentsOf: groupedChecks.map { check in
                let actionText = check.actionLabel.map { " Action: \($0)." } ?? ""
                return "- \(check.status.rawValue) \(check.title) [\(check.id)].\(actionText)"
            })
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
