import SwiftUI

@MainActor
struct SafetySectionCard: View {
    let section: LiveSafetyCockpitSection
    let onAction: @MainActor (LivePreflightActionKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(StudioTheme.sectionTitle())
                .foregroundStyle(StudioTheme.textSecondary)

            VStack(spacing: 8) {
                ForEach(section.checks) { check in
                    SafetyCheckRow(check: check, onAction: onAction)
                }
            }
        }
        .padding(14)
        .studioCard(cornerRadius: 18)
    }
}

@MainActor
struct SafetyCheckRow: View {
    let check: LivePreflightCheck
    let onAction: @MainActor (LivePreflightActionKind) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(StudioTheme.TypeScale.heading.weight(.black))
                .foregroundStyle(StudioTheme.color(for: statusKind))
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(check.title)
                        .font(StudioTheme.TypeScale.body.weight(.bold))
                        .foregroundStyle(StudioTheme.textPrimary)
                    StatusBadge(check.status.displayTitle, kind: statusKind)
                }

                Text(check.message)
                    .font(StudioTheme.TypeScale.caption)
                    .foregroundStyle(StudioTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let actionLabel = check.actionLabel, let actionKind = check.actionKind {
                    if actionKind.shouldRenderAsButton {
                        Button(actionLabel) {
                            onAction(actionKind)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help(help(for: actionKind))
                        .padding(.top, 2)
                    } else {
                        guidanceBadge(actionLabel, actionKind)
                            .padding(.top, 2)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(StudioTheme.color(for: statusKind).opacity(0.06), in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(StudioTheme.color(for: statusKind).opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(check.status.displayTitle): \(check.title). \(check.message)")
    }

    private var statusKind: StudioTheme.StatusKind {
        switch check.status {
        case .pass:
            return .ready
        case .warn:
            return .warn
        case .fail:
            return .fail
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

    private func guidanceBadge(_ label: String, _ action: LivePreflightActionKind) -> some View {
        Label(label, systemImage: guidanceIcon(for: action))
            .font(StudioTheme.TypeScale.caption.weight(.bold))
            .foregroundStyle(StudioTheme.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(StudioTheme.Surface.raised, in: Capsule())
            .help(help(for: action))
    }

    private func guidanceIcon(for action: LivePreflightActionKind) -> String {
        switch action {
        case .needsHardware:
            return "display.2"
        case .manualReview:
            return "person.crop.circle.badge.questionmark"
        case .clearOverlays, .turnOffPanic, .openPreview, .openAudioMixer, .openOverlays:
            return "info.circle"
        }
    }

    private func help(for action: LivePreflightActionKind) -> String {
        switch action {
        case .clearOverlays:
            return "清除倒计时、游动字幕和人名条。"
        case .turnOffPanic:
            return "关闭当前紧急切黑。"
        case .openPreview, .openAudioMixer, .openOverlays:
            return "打开主控制台对应页面，不改变上屏状态。"
        case .needsHardware:
            return "需要外接显示器硬件，无法自动完成。"
        case .manualReview:
            return "仅提示人工复核，不改变应用状态。"
        }
    }
}
