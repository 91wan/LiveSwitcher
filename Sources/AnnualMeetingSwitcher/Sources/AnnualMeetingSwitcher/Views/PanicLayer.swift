import SwiftUI

// MARK: - Tier1: Panic 黑屏遮罩（副屏最高优先级层）

struct PanicLayer: View {
    var body: some View {
        Color.black
            .ignoresSafeArea()
    }
}
