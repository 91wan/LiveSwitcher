import SwiftUI

struct BGMPanelStatusRow: View {
    let controls: BGMControlsState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(StudioTheme.color(for: controls.displayStatusKind))
                .frame(width: 8, height: 8)
            Text(BGMPanelStatusCopy.text(for: controls))
                .font(StudioTheme.TypeScale.body.weight(.semibold))
                .foregroundStyle(StudioTheme.textSecondary)
        }
    }
}
