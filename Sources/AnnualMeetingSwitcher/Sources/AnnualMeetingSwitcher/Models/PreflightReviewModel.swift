import Foundation

enum PreflightReviewMode: Hashable {
    case needsAttention
    case allChecks
}

struct PreflightReviewSection: Identifiable, Equatable {
    var id: String { group.rawValue }
    let group: LivePreflightGroup
    let title: String
    let checks: [LivePreflightCheck]
}

struct PreflightReviewModel: Equatable {
    let mode: PreflightReviewMode
    let checks: [LivePreflightCheck]
    let sections: [PreflightReviewSection]

    var isEmpty: Bool {
        checks.isEmpty
    }

    var rowCountText: String {
        "\(checks.count) rows"
    }

    var emptyTitle: String {
        switch mode {
        case .needsAttention:
            return "No rows need attention"
        case .allChecks:
            return "No preflight checks"
        }
    }

    var emptyMessage: String {
        switch mode {
        case .needsAttention:
            return "Switch to All checks if you want to audit every passing row."
        case .allChecks:
            return "No checks are available for the current runtime snapshot."
        }
    }

    static func make(checks: [LivePreflightCheck], mode: PreflightReviewMode) -> PreflightReviewModel {
        let sortedChecks = checks.sorted { lhs, rhs in
            let lhsRank = rank(lhs.status)
            let rhsRank = rank(rhs.status)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            return checkOrder(checks, lhs) < checkOrder(checks, rhs)
        }

        let displayedChecks: [LivePreflightCheck]
        switch mode {
        case .needsAttention:
            displayedChecks = sortedChecks.filter { $0.status != .pass }
        case .allChecks:
            displayedChecks = sortedChecks
        }

        let sections = LivePreflightGroup.allCases.compactMap { group -> PreflightReviewSection? in
            let groupChecks = displayedChecks.filter { $0.group == group }
            guard !groupChecks.isEmpty else { return nil }
            return PreflightReviewSection(
                group: group,
                title: group.displayTitle,
                checks: groupChecks
            )
        }

        return PreflightReviewModel(
            mode: mode,
            checks: displayedChecks,
            sections: sections
        )
    }

    private static func rank(_ status: LivePreflightStatus) -> Int {
        switch status {
        case .fail:
            return 0
        case .warn:
            return 1
        case .pass:
            return 2
        }
    }

    private static func checkOrder(_ checks: [LivePreflightCheck], _ check: LivePreflightCheck) -> Int {
        checks.firstIndex(where: { $0.id == check.id }) ?? Int.max
    }
}
