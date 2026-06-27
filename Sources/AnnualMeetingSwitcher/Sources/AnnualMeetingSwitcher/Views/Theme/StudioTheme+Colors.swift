import AppKit
import SwiftUI

extension StudioTheme {
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
    static let monitorGradient = LinearGradient(
        colors: [monitorSurfaceTop, monitorSurfaceBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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
}
