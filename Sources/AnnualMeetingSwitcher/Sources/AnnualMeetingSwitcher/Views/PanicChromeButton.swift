import SwiftUI

@MainActor
struct PanicChromeButton: View {
    let model: PanicButtonModel
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: model.systemImage)
                    .font(StudioTheme.TypeScale.heading.weight(.black))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(model.title)
                        .font(StudioTheme.TypeScale.body.weight(.black))
                        .lineLimit(1)
                    Text(model.subtitle)
                        .font(StudioTheme.TypeScale.label.weight(.bold))
                        .lineLimit(1)
                        .opacity(0.88)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(minWidth: model.minWidth)
            .frame(height: model.height)
            .background(
                RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                    .fill(StudioTheme.Action.danger)
            )
            .overlay(
                RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                    .stroke(StudioTheme.Surface.pressed.opacity(isActive ? 0.46 : 0.18), lineWidth: 1)
            )
            .shadow(color: StudioTheme.Action.danger.opacity(isActive ? 0.36 : 0.22), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(model.help)
        .accessibilityLabel(model.accessibilityLabel)
        .accessibilityHint(model.accessibilityHint)
    }
}
