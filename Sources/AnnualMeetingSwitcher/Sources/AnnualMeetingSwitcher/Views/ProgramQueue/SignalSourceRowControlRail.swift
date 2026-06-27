import SwiftUI

struct SignalSourceRowControlRail: View {
    let item: ProgramItem
    let rowModel: ProgramQueueRowModel
    let isHovered: Bool
    let controlTint: Color
    let rowContentIndent: CGFloat
    let onTogglePause: () -> Void
    let onEndHTML: () -> Void
    let onJumpToBeginning: () -> Void
    let onSkipToEnd: (() -> Void)?
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(rowModel.controlRailLabel)
                .font(StudioTheme.TypeScale.label)
                .foregroundStyle(controlTint)
                .lineLimit(1)

            HStack(spacing: 7) {
                switch rowModel.controlStyle {
                case .media:
                    controlButton(
                        systemName: rowModel.primarySystemName,
                        accessibilityLabel: rowModel.primaryAccessibilityLabel,
                        tint: .white,
                        fill: controlTint,
                        action: onTogglePause
                    )
                    .help(rowModel.primaryHelp)

                    controlButton(
                        systemName: "backward.end.fill",
                        accessibilityLabel: "跳回当前节目开头",
                        tint: controlTint,
                        fill: controlTint.opacity(0.12),
                        action: onJumpToBeginning
                    )
                    .help("跳回开头")

                    if let onSkipToEnd {
                        controlButton(
                            systemName: "forward.end.fill",
                            accessibilityLabel: "跳到当前节目结尾",
                            tint: controlTint,
                            fill: controlTint.opacity(0.12),
                            action: onSkipToEnd
                        )
                        .help("跳至结束")
                    }
                case .html:
                    controlButton(
                        systemName: rowModel.primarySystemName,
                        accessibilityLabel: rowModel.primaryAccessibilityLabel,
                        tint: .white,
                        fill: controlTint,
                        action: onEndHTML
                    )
                    .help(rowModel.primaryHelp)
                case .presentation:
                    controlButton(
                        systemName: rowModel.primarySystemName,
                        accessibilityLabel: rowModel.primaryAccessibilityLabel,
                        tint: .white,
                        fill: controlTint,
                        action: onTogglePause
                    )
                    .help(rowModel.primaryHelp)
                case .unsupported, .none:
                    EmptyView()
                }
            }

            Spacer(minLength: 0)

            controlButton(
                systemName: "trash",
                accessibilityLabel: "删除 \(item.title)",
                tint: StudioTheme.Action.danger,
                fill: StudioTheme.Action.danger.opacity(isHovered ? 0.12 : 0.04),
                action: onDelete
            )
            .opacity(isHovered ? 1 : 0.28)
            .help("删除")
        }
        .padding(.leading, rowContentIndent)
        .padding(.top, 2)
    }

    private func controlButton(
        systemName: String,
        accessibilityLabel: String,
        tint: Color,
        fill: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(StudioTheme.TypeScale.body.weight(.bold))
                .foregroundStyle(tint)
                .frame(
                    width: RunQueueLayoutMetrics.rowControlButtonSize,
                    height: RunQueueLayoutMetrics.rowControlButtonSize
                )
                .background(
                    RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                        .fill(fill)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
