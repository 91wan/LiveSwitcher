import SwiftUI

struct PreflightPopoverTitleBar: View {
    let summary: LivePreflightSummary

    var body: some View {
        HStack(spacing: 12) {
            Text("LiveSwitcher")
                .font(StudioTheme.TypeScale.heading.weight(.black))

            Spacer()

            let headerBadge = PreflightHeaderBadgeModel.make(summary: summary)
            if headerBadge.isVisible {
                StatusBadge(headerBadge.text, kind: headerBadge.kind)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }
}

struct PreflightSummaryHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("现场检查")
                .font(StudioTheme.TypeScale.numeric)
            Text("读取当前运行状态。先看汇总，再处理故障和警告项。")
                .font(StudioTheme.TypeScale.caption)
                .foregroundStyle(.secondary)
        }
    }
}
