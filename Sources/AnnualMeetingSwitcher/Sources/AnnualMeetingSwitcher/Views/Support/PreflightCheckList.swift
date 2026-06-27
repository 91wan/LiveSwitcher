import SwiftUI

@MainActor
struct PreflightCheckList: View {
    let summary: LivePreflightSummary
    let review: PreflightReviewModel
    @Binding var listMode: PreflightReviewMode
    let preflightActionMessage: String?
    let supportMessage: String?
    let onPreflightAction: @MainActor (LivePreflightActionKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PreflightSummaryHeader()

            PreflightSummaryCard(summary: summary)

            VStack(alignment: .leading, spacing: 8) {
                Picker("", selection: $listMode) {
                    Text("需处理").tag(PreflightReviewMode.needsAttention)
                    Text("全部检查").tag(PreflightReviewMode.allChecks)
                }
                .pickerStyle(.segmented)

                if listMode == .needsAttention {
                    Text("只显示故障和警告项，先处理现场风险。")
                        .font(StudioTheme.TypeScale.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let preflightActionMessage {
                PreflightMessageBanner(
                    message: preflightActionMessage,
                    foregroundStyle: StudioTheme.Tone.ready,
                    backgroundStyle: StudioTheme.Tone.ready.opacity(0.09),
                    accessibilityPrefix: "现场检查操作结果"
                )
            }

            if let supportMessage {
                PreflightMessageBanner(
                    message: supportMessage,
                    foregroundStyle: StudioTheme.Action.primary,
                    backgroundStyle: StudioTheme.Action.primary.opacity(0.09),
                    accessibilityPrefix: "支持报告结果"
                )
            }

            if review.isEmpty {
                PreflightEmptyAttentionView(
                    title: review.emptyTitle,
                    message: review.emptyMessage
                )
            }

            ForEach(review.sections) { section in
                PreflightGroupView(
                    group: section.group,
                    checks: section.checks,
                    onAction: onPreflightAction
                )
            }
        }
    }
}

private struct PreflightMessageBanner: View {
    let message: String
    let foregroundStyle: Color
    let backgroundStyle: Color
    let accessibilityPrefix: String

    var body: some View {
        Text(message)
            .font(StudioTheme.TypeScale.caption.weight(.bold))
            .foregroundStyle(foregroundStyle)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundStyle, in: RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous))
            .accessibilityLabel("\(accessibilityPrefix)：\(message)")
    }
}
