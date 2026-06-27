import SwiftUI

struct PreflightEmptyAttentionView: View {
    let title: String
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(StudioTheme.TypeScale.numeric)
                .foregroundStyle(StudioTheme.Tone.ready)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(StudioTheme.TypeScale.body.weight(.bold))
                Text(message)
                    .font(StudioTheme.TypeScale.caption)
                    .foregroundStyle(StudioTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(StudioTheme.Tone.ready.opacity(0.08), in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(StudioTheme.Tone.ready.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("没有需要处理的现场检查项")
    }
}

struct PreflightSummaryCard: View {
    let summary: LivePreflightSummary

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            Image(systemName: iconName)
                .font(StudioTheme.TypeScale.title.weight(.black))
                .foregroundStyle(statusColor)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(summary.title)
                        .font(StudioTheme.TypeScale.heading.weight(.black))

                    Text(summary.status.displayTitle)
                        .font(StudioTheme.TypeScale.label)
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.12), in: Capsule())
                }

                Text(summary.message)
                    .font(StudioTheme.TypeScale.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                countPill("过", summary.passCount, StudioTheme.Tone.ready)
                countPill("警", summary.warnCount, StudioTheme.Tone.warn)
                countPill("故障", summary.failCount, StudioTheme.Tone.fail)
            }
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .fill(statusColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(statusColor.opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("现场检查汇总：\(summary.status.displayTitle)。\(summary.message)。\(summary.passCount) 个通过，\(summary.warnCount) 个警告，\(summary.failCount) 个故障。")
    }

    private func countPill(_ label: String, _ count: Int, _ color: Color) -> some View {
        Text("\(label) \(count)")
            .font(StudioTheme.TypeScale.label)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color.opacity(0.10), in: Capsule())
    }

    private var statusColor: Color {
        switch summary.status {
        case .pass:
            return StudioTheme.Tone.ready
        case .warn:
            return StudioTheme.Tone.warn
        case .fail:
            return StudioTheme.Tone.fail
        }
    }

    private var iconName: String {
        switch summary.status {
        case .pass:
            return "checkmark.seal.fill"
        case .warn:
            return "exclamationmark.triangle.fill"
        case .fail:
            return "xmark.octagon.fill"
        }
    }
}

@MainActor
struct PreflightGroupView: View {
    let group: LivePreflightGroup
    let checks: [LivePreflightCheck]
    let onAction: @MainActor (LivePreflightActionKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.displayTitle)
                .font(StudioTheme.TypeScale.body.weight(.black))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(checks) { check in
                    PreflightRowView(check: check, onAction: onAction)
                }
            }
        }
    }
}

@MainActor
struct PreflightRowView: View {
    let check: LivePreflightCheck
    let onAction: @MainActor (LivePreflightActionKind) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(StudioTheme.TypeScale.heading.weight(.black))
                .foregroundStyle(statusColor)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(check.title)
                        .font(StudioTheme.TypeScale.body.weight(.bold))
                    Text(check.status.displayTitle)
                        .font(StudioTheme.TypeScale.label)
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.12), in: Capsule())
                }

                Text(check.message)
                    .font(StudioTheme.TypeScale.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let actionLabel = check.actionLabel, let actionKind = check.actionKind {
                    if actionKind.shouldRenderAsButton {
                        Button(actionLabel) {
                            onAction(actionKind)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help(PreflightPermissionSection.help(for: actionKind))
                        .accessibilityLabel(actionLabel)
                        .accessibilityHint(PreflightPermissionSection.help(for: actionKind))
                        .padding(.top, 3)
                    } else {
                        PreflightPermissionGuidanceBadge(label: actionLabel, action: actionKind)
                            .padding(.top, 3)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.84))
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(statusColor.opacity(0.18), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch check.status {
        case .pass:
            return StudioTheme.Tone.ready
        case .warn:
            return StudioTheme.Tone.warn
        case .fail:
            return StudioTheme.Tone.fail
        }
    }

    private var iconName: String {
        switch check.status {
        case .pass:
            return "checkmark.circle.fill"
        case .warn:
            return "exclamationmark.triangle.fill"
        case .fail:
            return "xmark.octagon.fill"
        }
    }
}
