import SwiftUI

extension ProgramMonitorView {
    var blackoutStatusOverlay: some View {
        let model = blackoutStatusModel

        return VStack(alignment: .center, spacing: 7) {
            Image(systemName: model.kind == .panic ? "exclamationmark.triangle.fill" : "moon.fill")
                .font(StudioTheme.TypeScale.title.weight(.black))
                .foregroundStyle(StudioTheme.color(for: model.statusKind))
                .accessibilityHidden(true)
            Text(model.title)
                .font(StudioTheme.TypeScale.title.weight(.black))
                .foregroundStyle(StudioTheme.monitorText)
                .lineLimit(1)
            if let subtitle = model.subtitle {
                Text(subtitle)
                    .font(StudioTheme.TypeScale.heading.weight(.semibold))
                    .foregroundStyle(StudioTheme.monitorText.opacity(0.72))
                    .lineLimit(1)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .frame(minWidth: 220)
        .background(StudioTheme.monitorOverlayFill, in: RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(StudioTheme.color(for: model.statusKind).opacity(0.78), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.monitorAccessibilityLabel ?? model.title)
    }
}
