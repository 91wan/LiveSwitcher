import Foundation

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

    static func formatPercent(_ volume: Float) -> String {
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
