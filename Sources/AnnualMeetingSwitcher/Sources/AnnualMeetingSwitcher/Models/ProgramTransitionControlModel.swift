import Foundation
import SwiftUI

enum ProgramTransitionControlTone: String, Equatable {
    case configuration

    var semanticToken: String {
        switch self {
        case .configuration:
            return "action.primary"
        }
    }

    var sliderTint: Color {
        switch self {
        case .configuration:
            return StudioTheme.Action.primary
        }
    }

    var valueTint: Color {
        switch self {
        case .configuration:
            return StudioTheme.textSecondary
        }
    }
}

struct ProgramTransitionControlModel: Equatable {
    let crossfadeDuration: Double

    var statusKind: StudioTheme.StatusKind {
        .idle
    }

    var controlTone: ProgramTransitionControlTone {
        .configuration
    }

    var title: String {
        "Program transition"
    }

    var subtitle: String {
        "节目画面切换动画时长，用于监看与输出媒体层过渡。"
    }

    var statusText: String {
        String(format: "%.1fs", crossfadeDuration)
    }

    var currentValueText: String {
        String(format: "当前：%.1fs", crossfadeDuration)
    }
}
