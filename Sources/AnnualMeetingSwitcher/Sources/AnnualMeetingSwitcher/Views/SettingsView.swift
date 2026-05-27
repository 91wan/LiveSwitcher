import SwiftUI

// MARK: - 叠层 / 字幕页面

@MainActor
struct SettingsView: View {
    @Environment(SwitcherViewModel.self) var viewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("叠层字幕")
                        .font(StudioTheme.titleLarge())
                        .foregroundStyle(StudioTheme.textPrimary)
                    Text("左侧编辑，右侧实时预览。输入为空时显示禁用原因，防止误上屏。")
                        .font(StudioTheme.body())
                        .foregroundStyle(StudioTheme.textSecondary)
                }

                OverlayControlPanel()
            }
            .frame(maxWidth: 1120, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(SwitcherViewModel())
        .frame(width: 900, height: 700)
}
