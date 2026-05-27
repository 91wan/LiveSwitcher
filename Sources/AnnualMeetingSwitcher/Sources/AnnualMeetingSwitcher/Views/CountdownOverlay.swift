import SwiftUI

// MARK: - Tier1: 倒计时叠层（副屏居中大字）

@MainActor
struct CountdownOverlay: View {
    @Environment(SwitcherViewModel.self) var viewModel

    var body: some View {
        // 居中显示，不影响视频播放区域（视频透过背景可见）
        VStack {
            Spacer()
            countdownCard
            Spacer()
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private var countdownCard: some View {
        VStack(spacing: 12) {
            // 标题（可自定义）
            Text(viewModel.countdownTitle)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))

            // 大字倒计时
            Text(formattedTime(viewModel.countdownSeconds))
                .font(.system(size: 192, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 8)
    }

    private func formattedTime(_ seconds: Int) -> String {
        let m = max(seconds, 0) / 60
        let s = max(seconds, 0) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
