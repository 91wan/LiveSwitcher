import SwiftUI

@MainActor
struct OverlayActiveStatusCard: View {
    @Environment(SwitcherViewModel.self) private var viewModel
    let hasActiveOverlay: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("上屏列表")
                    .font(StudioTheme.sectionTitle())
                    .foregroundStyle(StudioTheme.textPrimary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.clearAllOverlays()
                    }
                } label: {
                    Label("全部清空", systemImage: "xmark.circle.fill")
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!hasActiveOverlay)
            }

            summaryRow(title: "人名条", isLive: viewModel.isLowerThirdVisible)
            summaryRow(title: "倒计时", isLive: viewModel.isCountdownActive)
            summaryRow(title: "游动字幕", isLive: viewModel.isTickerActive)
        }
        .padding(12)
        .background(StudioTheme.Surface.raised, in: RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous))
    }

    private func summaryRow(title: String, isLive: Bool) -> some View {
        HStack {
            Text(title)
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textSecondary)
            Spacer()
            if isLive {
                StatusBadge("上屏", kind: .live)
            } else {
                Text("关闭")
                    .font(StudioTheme.caption().weight(.semibold))
                    .foregroundStyle(StudioTheme.textTertiary)
            }
        }
    }
}
