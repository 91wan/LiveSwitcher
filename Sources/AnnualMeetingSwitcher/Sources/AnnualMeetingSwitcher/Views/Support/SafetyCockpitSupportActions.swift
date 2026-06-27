import SwiftUI

struct SafetyCockpitSupportActions: View {
    let onCopySupportReport: @MainActor () -> Void
    let onSaveSupportReport: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 8) {
            SecondaryActionButton("复制支持报告", systemImage: "doc.on.doc") {
                onCopySupportReport()
            }

            Button("保存支持报告...") {
                onSaveSupportReport()
            }
            .buttonStyle(.bordered)
        }
    }
}
