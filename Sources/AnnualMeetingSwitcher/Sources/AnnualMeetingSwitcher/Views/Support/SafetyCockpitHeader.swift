import SwiftUI

struct SafetyCockpitHeader: View {
    let cockpit: LiveSafetyCockpitState
    let actionMessage: String?
    let supportMessage: String?
    let onCopySupportReport: @MainActor () -> Void
    let onSaveSupportReport: @MainActor () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            Image(systemName: headerIcon)
                .font(StudioTheme.TypeScale.display.weight(.black))
                .foregroundStyle(StudioTheme.color(for: headerKind))
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 5) {
                Text("现场安全台")
                    .font(StudioTheme.titleLarge())
                    .foregroundStyle(StudioTheme.textPrimary)
                Text(cockpit.summary.message)
                    .font(StudioTheme.body())
                    .foregroundStyle(StudioTheme.textSecondary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 7) {
                    CountPill("通过 \(cockpit.summary.passCount)", kind: .ready)
                    CountPill("警告 \(cockpit.summary.warnCount)", kind: .warn)
                    CountPill("故障 \(cockpit.summary.failCount)", kind: .fail)
                }

                SafetyCockpitSupportActions(
                    onCopySupportReport: onCopySupportReport,
                    onSaveSupportReport: onSaveSupportReport
                )
                .controlSize(.small)
            }
        }
        .padding(18)
        .background(StudioTheme.color(for: headerKind).opacity(0.09), in: RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(StudioTheme.color(for: headerKind).opacity(0.24), lineWidth: 1)
        )
        .overlay(alignment: .bottomLeading) {
            if let actionMessage {
                messageBanner(actionMessage, color: StudioTheme.Tone.ready)
                    .offset(y: 42)
            } else if let supportMessage {
                messageBanner(supportMessage, color: StudioTheme.Action.primary)
                    .offset(y: 42)
            }
        }
        .padding(.bottom, (actionMessage == nil && supportMessage == nil) ? 0 : 34)
    }

    private var headerKind: StudioTheme.StatusKind {
        switch cockpit.summary.status {
        case .pass:
            return .ready
        case .warn:
            return .warn
        case .fail:
            return .fail
        }
    }

    private var headerIcon: String {
        switch cockpit.summary.status {
        case .pass:
            return "checkmark.seal.fill"
        case .warn:
            return "exclamationmark.triangle.fill"
        case .fail:
            return "xmark.octagon.fill"
        }
    }

    private func messageBanner(_ message: String, color: Color) -> some View {
        Text(message)
            .font(StudioTheme.TypeScale.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(color.opacity(0.10), in: Capsule())
    }
}
