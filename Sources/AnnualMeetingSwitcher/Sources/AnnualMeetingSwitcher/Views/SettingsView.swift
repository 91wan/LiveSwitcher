import SwiftUI

// MARK: - 叠层 / 字幕页面

struct SettingsView: View {
    @EnvironmentObject var viewModel: SwitcherViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Overlays / 叠层字幕")
                        .font(StudioTheme.titleLarge())
                        .foregroundStyle(StudioTheme.textPrimary)
                    Text("左侧控制上屏，右侧预览位置和当前 live 状态。输入为空时会显示禁用原因，避免误上屏。")
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
        .environmentObject(SwitcherViewModel())
        .frame(width: 900, height: 700)
}
