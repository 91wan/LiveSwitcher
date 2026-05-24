import Foundation

struct PreflightHeaderBadgeModel: Equatable {
    let text: String
    let kind: StudioTheme.StatusKind
    let isVisible: Bool

    static func make(summary: LivePreflightSummary) -> PreflightHeaderBadgeModel {
        let preflight = PreflightButtonModel.make(summary: summary)
        return PreflightHeaderBadgeModel(
            text: preflight.title,
            kind: preflight.status,
            isVisible: StatusBadgeVisibilityPolicy.shouldShow(
                text: preflight.title,
                kind: preflight.status
            )
        )
    }
}
