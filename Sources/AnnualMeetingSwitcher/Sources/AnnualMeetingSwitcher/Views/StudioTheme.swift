import SwiftUI

enum StudioTheme {
    static let canvasTop = Color(red: 0.97, green: 0.98, blue: 1.00)
    static let canvasBottom = Color(red: 0.94, green: 0.96, blue: 0.99)

    static let cardFill = Color.white.opacity(0.88)
    static let cardBorder = Color.white.opacity(0.82)
    static let hairline = Color.black.opacity(0.06)
    static let shadow = Color.black.opacity(0.10)

    static let accent = Color(red: 0.12, green: 0.49, blue: 0.96)
    static let accentSecondary = Color(red: 0.42, green: 0.35, blue: 0.95)
    static let green = Color(red: 0.12, green: 0.71, blue: 0.42)
    static let orange = Color(red: 1.00, green: 0.57, blue: 0.15)
    static let pink = Color(red: 0.84, green: 0.24, blue: 0.83)

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
