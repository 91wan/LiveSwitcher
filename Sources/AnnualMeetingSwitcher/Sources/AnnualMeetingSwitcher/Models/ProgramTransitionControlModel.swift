import Foundation

struct ProgramTransitionControlModel: Equatable {
    let crossfadeDuration: Double

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
