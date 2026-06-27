import Foundation

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
