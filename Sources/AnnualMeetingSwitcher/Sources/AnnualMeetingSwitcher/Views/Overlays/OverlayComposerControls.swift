import SwiftUI

struct OverlayComposerSection<Content: View>: View {
    let kind: OverlayComposerKind
    let isLive: Bool
    let hasDraftInput: Bool
    let disabledReason: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label(kind.title, systemImage: kind.systemImage)
                    .font(StudioTheme.TypeScale.heading.weight(.bold))
                    .foregroundStyle(StudioTheme.textPrimary)
                Spacer()
                OverlayComposerStatusBadge(
                    title: OverlayComposerStatus.text(
                        isLive: isLive,
                        hasDraftInput: hasDraftInput,
                        disabledReason: disabledReason
                    ),
                    isLive: isLive
                )
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.Surface.base.opacity(StudioTheme.Surface.Opacity.medium))
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(isLive ? StudioTheme.borderCritical.opacity(0.50) : StudioTheme.borderSubtle, lineWidth: 1)
        )
    }
}

struct OverlayComposerStatusBadge: View {
    let title: String
    let isLive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isLive ? StudioTheme.Tone.live : StudioTheme.Tone.idle.opacity(0.45))
                .frame(width: 7, height: 7)
            Text(title)
                .font(StudioTheme.TypeScale.label.weight(.black))
        }
        .foregroundStyle(isLive ? StudioTheme.Tone.live : StudioTheme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(isLive ? StudioTheme.Tone.live.opacity(0.12) : StudioTheme.Surface.raised)
        )
    }
}

struct OverlayActionButton: View {
    let title: String
    let systemImage: String
    let fill: Color
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(StudioTheme.TypeScale.body.weight(.bold))
                .foregroundStyle(isDisabled ? .white.opacity(0.55) : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                        .fill(isDisabled ? fill.opacity(0.25) : fill)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(title)
        .accessibilityHint(isDisabled ? "当前叠层操作不可用。" : "执行叠层操作。")
    }
}

struct OverlayDisabledReasonText: View {
    let reason: String?

    var body: some View {
        if let reason {
            Text(reason)
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textTertiary)
        }
    }
}

struct OverlayNumberInput: View {
    let title: String
    let value: Binding<Int>

    var body: some View {
        HStack(spacing: 4) {
            TextField("0", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 58)
                .multilineTextAlignment(.center)
                .font(StudioTheme.TypeScale.mono.weight(.medium))
            Text(title)
                .font(StudioTheme.TypeScale.body.weight(.medium))
                .foregroundStyle(StudioTheme.textSecondary)
        }
    }
}

func overlayFormattedTime(_ seconds: Int) -> String {
    let minutes = max(seconds, 0) / 60
    let remainingSeconds = max(seconds, 0) % 60
    return String(format: "%02d:%02d", minutes, remainingSeconds)
}
