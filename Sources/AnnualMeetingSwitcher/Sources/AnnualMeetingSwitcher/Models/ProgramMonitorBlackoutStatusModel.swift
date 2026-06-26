import Foundation

enum ProgramMonitorBlackoutKind: Equatable {
    case none
    case fadeToBlack
    case panic
}

struct ProgramMonitorBlackoutStatusModel: Equatable {
    let kind: ProgramMonitorBlackoutKind
    let title: String
    let subtitle: String?
    let statusKind: StudioTheme.StatusKind

    var monitorAccessibilityLabel: String? {
        switch kind {
        case .none:
            nil
        case .fadeToBlack:
            "主输出监看：切黑已启用"
        case .panic:
            "主输出监看：紧急切黑已启用"
        }
    }

    static func make(
        isFadeToBlackActive: Bool,
        isPanicMode: Bool
    ) -> ProgramMonitorBlackoutStatusModel {
        if isPanicMode {
            return ProgramMonitorBlackoutStatusModel(
                kind: .panic,
                title: "紧急切黑",
                subtitle: "观众正在看到黑场",
                statusKind: .fail
            )
        }

        if isFadeToBlackActive {
            return ProgramMonitorBlackoutStatusModel(
                kind: .fadeToBlack,
                title: "切黑中",
                subtitle: "观众正在看到黑场",
                statusKind: .warn
            )
        }

        return ProgramMonitorBlackoutStatusModel(
            kind: .none,
            title: "",
            subtitle: nil,
            statusKind: .idle
        )
    }
}
