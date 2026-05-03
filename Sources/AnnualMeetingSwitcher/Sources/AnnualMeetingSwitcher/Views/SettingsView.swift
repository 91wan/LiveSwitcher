import SwiftUI

// MARK: - 叠层 / 字幕页面

struct SettingsView: View {
    @EnvironmentObject var viewModel: SwitcherViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("叠层 / 字幕")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("集中管理人名条、倒计时和游动字幕，所有控件都直接作用于输出大屏。")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                OverlayControlPanel()
            }
            .frame(maxWidth: 800, alignment: .leading)
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
