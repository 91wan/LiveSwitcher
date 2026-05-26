import SwiftUI

struct PresentationReadinessDot: View {
    let result: PresentationReadinessResult

    var body: some View {
        if result.severity != .notApplicable {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(StudioTheme.Surface.base.opacity(0.75), lineWidth: 1)
                )
                .help(result.operatorMessage)
                .accessibilityLabel("演示就绪状态")
                .accessibilityValue(result.dotLabel ?? "")
        }
    }

    private var color: Color {
        switch result.severity {
        case .notApplicable:
            return StudioTheme.Tone.idle
        case .ready:
            return StudioTheme.Tone.ready
        case .warning:
            return StudioTheme.Tone.warn
        case .blocked:
            return StudioTheme.Tone.fail
        }
    }
}
