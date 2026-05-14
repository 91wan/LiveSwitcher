import SwiftUI

enum StudioTheme {
    enum StatusKind: String, Equatable {
        case ready
        case live
        case warn
        case fail
        case muted
        case idle

        var accessibilityName: String {
            switch self {
            case .ready: return "Ready"
            case .live: return "On Air"
            case .warn: return "Warning"
            case .fail: return "Fail"
            case .muted: return "Muted"
            case .idle: return "Idle"
            }
        }
    }

    static let canvasTop = Color(red: 0.97, green: 0.98, blue: 1.00)
    static let canvasBottom = Color(red: 0.94, green: 0.96, blue: 0.99)

    // Semantic status colors. Keep red reserved for danger/failure/live output.
    static let statusReady = Color(red: 0.10, green: 0.58, blue: 0.32)
    static let statusLive = Color(red: 0.82, green: 0.14, blue: 0.12)
    static let statusWarn = Color(red: 0.88, green: 0.45, blue: 0.08)
    static let statusFail = Color(red: 0.78, green: 0.10, blue: 0.10)
    static let statusMuted = Color(red: 0.39, green: 0.42, blue: 0.48)
    static let statusIdle = Color(red: 0.45, green: 0.49, blue: 0.55)

    static let actionPrimary = Color(red: 0.12, green: 0.42, blue: 0.88)
    static let actionSecondary = Color(red: 0.25, green: 0.28, blue: 0.34)
    static let actionDanger = statusFail

    static let surfacePrimary = Color.white.opacity(0.92)
    static let surfaceSecondary = Color(red: 0.96, green: 0.97, blue: 0.99)
    static let surfaceElevated = Color.white.opacity(0.98)

    static let textPrimary = Color(red: 0.12, green: 0.13, blue: 0.16)
    static let textSecondary = Color(red: 0.43, green: 0.45, blue: 0.50)
    static let textTertiary = Color(red: 0.58, green: 0.60, blue: 0.65)

    static let borderSubtle = Color.black.opacity(0.07)
    static let borderActive = actionPrimary.opacity(0.38)
    static let borderCritical = statusLive.opacity(0.72)

    static let cardFill = Color.white.opacity(0.88)
    static let cardBorder = Color.white.opacity(0.82)
    static let hairline = Color.black.opacity(0.06)
    static let shadow = Color.black.opacity(0.10)

    static let accent = Color(red: 0.12, green: 0.49, blue: 0.96)
    static let accentSecondary = Color(red: 0.42, green: 0.35, blue: 0.95)
    static let green = Color(red: 0.12, green: 0.71, blue: 0.42)
    static let orange = Color(red: 1.00, green: 0.57, blue: 0.15)
    static let pink = Color(red: 0.84, green: 0.24, blue: 0.83)

    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 18
    static let spacingXL: CGFloat = 26

    static let radiusS: CGFloat = 8
    static let radiusM: CGFloat = 12
    static let radiusL: CGFloat = 18
    static let radiusXL: CGFloat = 26

    static let controlHeightS: CGFloat = 30
    static let controlHeightM: CGFloat = 38
    static let controlHeightL: CGFloat = 46

    static let directorRailWidth: CGFloat = 348

    static let canvasGradient = LinearGradient(
        colors: [canvasTop, canvasBottom],
        startPoint: .top,
        endPoint: .bottom
    )

    static let accentGradient = LinearGradient(
        colors: [accent, accentSecondary],
        startPoint: .leading,
        endPoint: .trailing
    )

    static func statusColor(_ kind: StatusKind) -> Color {
        switch kind {
        case .ready: return statusReady
        case .live: return statusLive
        case .warn: return statusWarn
        case .fail: return statusFail
        case .muted: return statusMuted
        case .idle: return statusIdle
        }
    }

    static func titleLarge() -> Font { .system(size: 30, weight: .black) }
    static func title() -> Font { .system(size: 22, weight: .black) }
    static func sectionTitle() -> Font { .system(size: 15, weight: .black) }
    static func body() -> Font { .system(size: 13, weight: .medium) }
    static func caption() -> Font { .system(size: 11, weight: .semibold) }
    static func numeric() -> Font { .system(size: 18, weight: .black, design: .rounded) }
    static func statusLabel() -> Font { .system(size: 10, weight: .black, design: .rounded) }
}

struct StudioCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 26

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(StudioTheme.cardFill)
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
                    if let status {
                        StatusBadge(status.0, kind: status.1)
                    }
                }
            }

            content
        }
        .padding(StudioTheme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
    }
}

struct StatusBadge: View {
    let text: String
    let kind: StudioTheme.StatusKind
    let systemImage: String?

    init(_ text: String, kind: StudioTheme.StatusKind, systemImage: String? = nil) {
        self.text = text
        self.kind = kind
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .black))
            }
            Text(text)
                .font(StudioTheme.statusLabel())
                .lineLimit(1)
        }
        .foregroundStyle(StudioTheme.statusColor(kind))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(StudioTheme.statusColor(kind).opacity(0.12))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(StudioTheme.statusColor(kind).opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.accessibilityName): \(text)")
    }
}

struct CountPill: View {
    let text: String
    let kind: StudioTheme.StatusKind

    init(_ text: String, kind: StudioTheme.StatusKind = .idle) {
        self.text = text
        self.kind = kind
    }

    var body: some View {
        Text(text)
            .font(StudioTheme.statusLabel())
            .foregroundStyle(StudioTheme.statusColor(kind))
            .padding(.horizontal, 9)
            .frame(height: StudioTheme.controlHeightS)
            .background(StudioTheme.statusColor(kind).opacity(0.11), in: Capsule(style: .continuous))
            .accessibilityLabel(text)
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
                .font(.system(size: 22, weight: .semibold))
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
        .background(StudioTheme.surfaceSecondary, in: RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous))
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
                    .font(.system(size: 15, weight: .black))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .black))
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
                    .fill(isActive ? StudioTheme.actionDanger : StudioTheme.actionPrimary)
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
                        .font(.system(size: 12, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 12, weight: .bold))
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
        role.map(StudioTheme.statusColor) ?? StudioTheme.actionSecondary
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
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(isSelected ? .white : StudioTheme.textPrimary)
            .padding(.horizontal, 16)
            .frame(height: StudioTheme.controlHeightL)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? StudioTheme.actionPrimary : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

struct MetricRow: View {
    let title: String
    let value: String
    let subtitle: String?
    let kind: StudioTheme.StatusKind

    init(title: String, value: String, subtitle: String? = nil, kind: StudioTheme.StatusKind = .idle) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.kind = kind
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: StudioTheme.spacingM) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textSecondary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(StudioTheme.textTertiary)
                }
            }
            Spacer(minLength: 0)
            Text(value)
                .font(StudioTheme.numeric())
                .foregroundStyle(StudioTheme.statusColor(kind))
        }
        .accessibilityElement(children: .combine)
    }
}

struct InlineWarningBanner: View {
    let title: String
    let message: String
    let kind: StudioTheme.StatusKind

    init(title: String, message: String, kind: StudioTheme.StatusKind = .warn) {
        self.title = title
        self.message = message
        self.kind = kind
    }

    var body: some View {
        HStack(alignment: .top, spacing: StudioTheme.spacingS) {
            Image(systemName: kind == .fail ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(StudioTheme.statusColor(kind))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(StudioTheme.textPrimary)
                Text(message)
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(StudioTheme.spacingM)
        .background(StudioTheme.statusColor(kind).opacity(0.09), in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(StudioTheme.statusColor(kind).opacity(0.20), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
