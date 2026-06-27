import SwiftUI

struct ProgramRailFooter: View {
    let programCount: Int
    let currentTitle: String

    var body: some View {
        SetupSideRailFooter(
            text: "共 \(programCount) 个节目 · \(currentTitle)",
            accessibilityLabel: "节目单底部。\(programCount) 个节目。当前 \(currentTitle)。",
            truncationMode: .middle
        )
    }
}
