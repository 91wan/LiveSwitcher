import AppKit
import SwiftUI

enum StudioTheme {
    private struct ThemeRGBA {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat

        init(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }

        var nsColor: NSColor {
            NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
        }
    }

    private static func dynamicColor(name: String, light: ThemeRGBA, dark: ThemeRGBA) -> Color {
        let color = NSColor(name: NSColor.Name("LiveSwitcher.\(name)"), dynamicProvider: { appearance in
            let match = appearance.bestMatch(from: [
                .accessibilityHighContrastDarkAqua,
                .darkAqua,
                .accessibilityHighContrastAqua,
                .aqua
            ])
            let isDark = match == .darkAqua || match == .accessibilityHighContrastDarkAqua
            return (isDark ? dark : light).nsColor
        })
        return Color(nsColor: color)
    }

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

    enum Tone {
        static let ready = dynamicColor(name: "ready", light: ThemeRGBA(0.10, 0.58, 0.32), dark: ThemeRGBA(0.32, 0.78, 0.50))
        static let live = dynamicColor(name: "live", light: ThemeRGBA(0.82, 0.14, 0.12), dark: ThemeRGBA(0.95, 0.30, 0.28))
        static let warn = dynamicColor(name: "warn", light: ThemeRGBA(0.88, 0.45, 0.08), dark: ThemeRGBA(1.00, 0.62, 0.20))
        static let fail = live
        static let muted = dynamicColor(name: "muted", light: ThemeRGBA(0.39, 0.42, 0.48), dark: ThemeRGBA(0.54, 0.56, 0.62))
        static let idle = dynamicColor(name: "idle", light: ThemeRGBA(0.45, 0.49, 0.55), dark: ThemeRGBA(0.58, 0.61, 0.68))
    }

    enum Action {
        static let primary = dynamicColor(name: "primary", light: ThemeRGBA(0.12, 0.49, 0.96), dark: ThemeRGBA(0.30, 0.62, 1.00))
        static let secondary = dynamicColor(name: "secondary", light: ThemeRGBA(0.25, 0.28, 0.34), dark: ThemeRGBA(0.62, 0.68, 0.76))
        static var danger: Color { Tone.fail }
    }

    enum Surface {
        enum Opacity {
            static let subtle = 0.55
            static let medium = 0.72
            static let strong = 0.92
            static let overlay = 0.78
        }

        static let base = dynamicColor(name: "base", light: ThemeRGBA(1.00, 1.00, 1.00, Opacity.strong), dark: ThemeRGBA(0.18, 0.19, 0.22, 0.96))
        static let raised = dynamicColor(name: "raised", light: ThemeRGBA(0.96, 0.97, 0.99), dark: ThemeRGBA(0.24, 0.25, 0.28))
        static let pressed = dynamicColor(name: "pressed", light: ThemeRGBA(1.00, 1.00, 1.00, 0.98), dark: ThemeRGBA(0.30, 0.31, 0.34))
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum TypeScale {
        static let display = Font.system(size: 28, weight: .bold)
        static let title = Font.system(size: 20, weight: .bold)
        static let heading = Font.system(size: 15, weight: .semibold)
        static let body = Font.system(size: 13, weight: .regular)
        static let caption = Font.system(size: 11, weight: .medium)
        static let mono = Font.system(size: 13, weight: .medium, design: .monospaced)
        static let monoCaption = Font.system(size: 10, weight: .bold, design: .monospaced)
        static let label = Font.system(size: 10, weight: .heavy, design: .rounded)
        static let numeric = Font.system(size: 18, weight: .black, design: .rounded)
    }

    static let canvasTop = dynamicColor(name: "canvasTop", light: ThemeRGBA(0.97, 0.98, 1.00), dark: ThemeRGBA(0.10, 0.10, 0.12))
    static let canvasBottom = dynamicColor(name: "canvasBottom", light: ThemeRGBA(0.94, 0.96, 0.99), dark: ThemeRGBA(0.07, 0.07, 0.09))

    static let textPrimary = dynamicColor(name: "textPrimary", light: ThemeRGBA(0.12, 0.13, 0.16), dark: ThemeRGBA(0.92, 0.93, 0.95))
    static let textSecondary = dynamicColor(name: "textSecondary", light: ThemeRGBA(0.43, 0.45, 0.50), dark: ThemeRGBA(0.65, 0.67, 0.72))
    static let textTertiary = dynamicColor(name: "textTertiary", light: ThemeRGBA(0.58, 0.60, 0.65), dark: ThemeRGBA(0.50, 0.52, 0.58))

    static let borderSubtle = dynamicColor(name: "borderSubtle", light: ThemeRGBA(0.00, 0.00, 0.00, 0.07), dark: ThemeRGBA(1.00, 1.00, 1.00, 0.10))
    static let borderActive = Action.primary.opacity(0.38)
    static let borderCritical = Tone.live.opacity(Surface.Opacity.medium)

    static let cardBorder = dynamicColor(name: "cardBorder", light: ThemeRGBA(1.00, 1.00, 1.00, 0.82), dark: ThemeRGBA(1.00, 1.00, 1.00, 0.10))
    static let hairline = dynamicColor(name: "hairline", light: ThemeRGBA(0.00, 0.00, 0.00, 0.06), dark: ThemeRGBA(1.00, 1.00, 1.00, 0.08))
    static let shadow = dynamicColor(name: "shadow", light: ThemeRGBA(0.00, 0.00, 0.00, 0.10), dark: ThemeRGBA(0.00, 0.00, 0.00, 0.42))
    static let shadowSoft = dynamicColor(name: "shadowSoft", light: ThemeRGBA(0.00, 0.00, 0.00, 0.05), dark: ThemeRGBA(0.00, 0.00, 0.00, 0.30))
    static let shadowStrong = dynamicColor(name: "shadowStrong", light: ThemeRGBA(0.00, 0.00, 0.00, 0.18), dark: ThemeRGBA(0.00, 0.00, 0.00, 0.55))

    static let monitorSurfaceTop = Color(red: 0.08, green: 0.09, blue: 0.13)
    static let monitorSurfaceBottom = Color(red: 0.03, green: 0.03, blue: 0.05)
    static let monitorBorder = Color.white.opacity(0.08)
    static let monitorText = Color.white
    static let monitorOverlayFill = Color.white.opacity(0.08)
    static let monitorRadius: CGFloat = 24
    static let monitorGradient = LinearGradient(
        colors: [monitorSurfaceTop, monitorSurfaceBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let spacingXS = Spacing.xxs
    static let spacingS = Spacing.xs
    static let spacingM = Spacing.s
    static let spacingL = Spacing.l
    static let spacingXL = Spacing.xl

    static let radiusS = Radius.s
    static let radiusM = Radius.m
    static let radiusL = Radius.l
    static let radiusXL = Radius.xl

    static let controlHeightS: CGFloat = 30
    static let controlHeightM: CGFloat = 38
    static let controlHeightL: CGFloat = 46

    static let directorRailWidth: CGFloat = 320

    static let canvasGradient = LinearGradient(
        colors: [canvasTop, canvasBottom],
        startPoint: .top,
        endPoint: .bottom
    )

    static let actionGradient = LinearGradient(
        colors: [Action.primary, Action.secondary],
        startPoint: .leading,
        endPoint: .trailing
    )

    static func color(for kind: StatusKind) -> Color {
        switch kind {
        case .ready: return Tone.ready
        case .live: return Tone.live
        case .warn: return Tone.warn
        case .fail: return Tone.fail
        case .muted: return Tone.muted
        case .idle: return Tone.idle
        }
    }

    static func titleLarge() -> Font { TypeScale.display }
    static func title() -> Font { TypeScale.title }
    static func sectionTitle() -> Font { TypeScale.heading }
    static func body() -> Font { TypeScale.body }
    static func caption() -> Font { TypeScale.caption }
    static func statusLabel() -> Font { TypeScale.label }
}

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
                .fill(StudioTheme.Surface.base)
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
        .foregroundStyle(StudioTheme.color(for: kind))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(StudioTheme.color(for: kind).opacity(0.12))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(StudioTheme.color(for: kind).opacity(0.22), lineWidth: 1)
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
            .foregroundStyle(StudioTheme.color(for: kind))
            .padding(.horizontal, 9)
            .frame(height: StudioTheme.controlHeightS)
            .background(StudioTheme.color(for: kind).opacity(0.11), in: Capsule(style: .continuous))
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
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(isSelected ? .white : StudioTheme.textPrimary)
            .padding(.horizontal, 16)
            .frame(height: StudioTheme.controlHeightL)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? StudioTheme.Action.primary : Color.clear)
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
                .font(StudioTheme.TypeScale.numeric)
                .foregroundStyle(StudioTheme.color(for: kind))
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

    var iconName: String {
        switch kind {
        case .fail:
            return "xmark.octagon.fill"
        case .warn:
            return "exclamationmark.triangle.fill"
        case .ready:
            return "checkmark.seal.fill"
        case .live:
            return "dot.radiowaves.left.and.right"
        case .idle, .muted:
            return "info.circle.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: StudioTheme.spacingS) {
            Image(systemName: iconName)
                .foregroundStyle(StudioTheme.color(for: kind))
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
        .background(StudioTheme.color(for: kind).opacity(0.09), in: RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(StudioTheme.color(for: kind).opacity(0.20), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
