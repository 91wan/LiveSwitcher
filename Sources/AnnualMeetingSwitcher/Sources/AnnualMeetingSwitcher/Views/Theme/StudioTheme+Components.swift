import SwiftUI

struct StudioCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 26

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(StudioTheme.Surface.base)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(StudioTheme.cardBorder, lineWidth: 1)
            )
            .shadow(color: StudioTheme.shadow, radius: 22, x: 0, y: 10)
    }
}

extension View {
    func studioCard(cornerRadius: CGFloat = 26) -> some View {
        modifier(StudioCardModifier(cornerRadius: cornerRadius))
    }
}

struct StudioSectionCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    let status: (String, StudioTheme.StatusKind)?
    @ViewBuilder var content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        status: (String, StudioTheme.StatusKind)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StudioTheme.spacingM) {
            if title != nil || subtitle != nil || status != nil {
                HStack(alignment: .firstTextBaseline, spacing: StudioTheme.spacingS) {
                    VStack(alignment: .leading, spacing: 2) {
                        if let title {
                            Text(title)
                                .font(StudioTheme.sectionTitle())
                                .foregroundStyle(StudioTheme.textPrimary)
                        }
                        if let subtitle {
                            Text(subtitle)
                                .font(StudioTheme.caption())
                                .foregroundStyle(StudioTheme.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                    if let status,
                       StatusBadgeVisibilityPolicy.shouldShow(text: status.0, kind: status.1) {
                        StatusBadge(status.0, kind: status.1)
                    }
                }
            }

            content
        }
        .padding(StudioTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.Surface.base)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    init(title: String, message: String, systemImage: String = "tray") {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }

    var body: some View {
        VStack(spacing: StudioTheme.spacingS) {
            Image(systemName: systemImage)
                .font(StudioTheme.TypeScale.title.weight(.semibold))
                .foregroundStyle(StudioTheme.textTertiary)
            Text(title)
                .font(StudioTheme.sectionTitle())
                .foregroundStyle(StudioTheme.textPrimary)
            Text(message)
                .font(StudioTheme.caption())
                .multilineTextAlignment(.center)
                .foregroundStyle(StudioTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(StudioTheme.spacingL)
        .background(StudioTheme.Surface.raised, in: RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct CriticalActionButton: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let isActive: Bool
    let action: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.isActive = isActive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: StudioTheme.spacingS) {
                Image(systemName: systemImage)
                    .font(StudioTheme.TypeScale.heading.weight(.black))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(StudioTheme.TypeScale.body.weight(.black))
                    if let subtitle {
                        Text(subtitle)
                            .font(StudioTheme.caption())
                            .opacity(0.88)
                    }
                }
            }
            .foregroundStyle(.white)
            .frame(minWidth: 104, minHeight: StudioTheme.controlHeightL)
            .padding(.horizontal, StudioTheme.spacingM)
            .background(
                RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                    .fill(isActive ? StudioTheme.Action.danger : StudioTheme.Action.primary)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle ?? "")
    }
}

struct SecondaryActionButton: View {
    let title: String
    let systemImage: String?
    let role: StudioTheme.StatusKind?
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        role: StudioTheme.StatusKind? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                }
                Text(title)
                    .font(StudioTheme.TypeScale.caption.weight(.bold))
            }
            .foregroundStyle(tint)
            .frame(minHeight: StudioTheme.controlHeightM)
            .padding(.horizontal, StudioTheme.spacingM)
            .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var tint: Color {
        role.map { StudioTheme.color(for: $0) } ?? StudioTheme.Action.secondary
    }
}

struct NavigationTabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(StudioTheme.TypeScale.body.weight(.semibold))
                Text(title)
                    .font(StudioTheme.TypeScale.heading.weight(.bold))
            }
            .foregroundStyle(isSelected ? .white : StudioTheme.textPrimary)
            .padding(.horizontal, 16)
            .frame(height: StudioTheme.controlHeightL)
            .background(
                RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                    .fill(isSelected ? StudioTheme.Action.primary : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                    .stroke(isSelected ? StudioTheme.Action.primary.opacity(0.36) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}
