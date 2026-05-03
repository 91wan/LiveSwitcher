import SwiftUI

// MARK: - Tier1: Panic 黑屏遮罩（副屏最高优先级层）

struct PanicLayer: View {
    var body: some View {
        Color.black
            .ignoresSafeArea()
            // 中心提示（可选：帮助调试，生产时保持纯黑）
            // Text("• 休息中 •")
            //     .font(.system(size: 24, weight: .thin))
            //     .foregroundColor(Color.white.opacity(0.15))
    }
}
