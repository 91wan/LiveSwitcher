import SwiftUI

// MARK: - 设置页面（叠层控制 · 系统设置）

struct SettingsView: View {
    @EnvironmentObject var viewModel: SwitcherViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ── 内容（限宽居中）──
                VStack(spacing: 20) {
                    OverlayControlPanel()
                }
                .frame(maxWidth: 800)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)
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
