import SwiftUI

struct PreflightSupportActions: View {
    let copiedReport: Bool
    let onOpenSafetyCockpit: @MainActor () -> Void
    let onCopyPreflightReport: @MainActor () -> Void
    let onCopySupportReport: @MainActor () -> Void
    let onSaveSupportReport: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            HStack(spacing: 8) {
                Button(action: onOpenSafetyCockpit) {
                    Label("打开安全台", systemImage: "gauge.with.dots.needle.bottom.100percent")
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(action: onCopyPreflightReport) {
                    Label(copiedReport ? "已复制" : "复制检查", systemImage: copiedReport ? "checkmark" : "doc.on.doc")
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer(minLength: 0)

                Button(action: onCopySupportReport) {
                    Label("复制支持报告", systemImage: "stethoscope")
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: onSaveSupportReport) {
                    Label("保存支持报告...", systemImage: "square.and.arrow.down")
                        .font(StudioTheme.TypeScale.caption.weight(.bold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("现场检查底部操作")
    }
}
