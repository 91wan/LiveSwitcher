import SwiftUI

struct SignalSourceRowStatusChips: View {
    let item: ProgramItem
    let rowModel: ProgramQueueRowModel
    let queueRole: QueueRole
    let isBroadcasting: Bool
    let rowContentIndent: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            stateBadge
            sourceTypeChip
            Spacer(minLength: 0)
        }
        .padding(.leading, rowContentIndent)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var stateBadge: some View {
        switch queueRole {
        case .current:
            badge(
                text: rowModel.stateBadgeText ?? "",
                foreground: .white,
                background: isBroadcasting ? StudioTheme.Tone.live : StudioTheme.Action.primary
            )
        case .next:
            badge(
                text: rowModel.stateBadgeText ?? "下一项",
                foreground: StudioTheme.Tone.warn,
                background: StudioTheme.Tone.warn.opacity(0.14)
            )
        case .queued:
            EmptyView()
        }
    }

    private var sourceTypeChip: some View {
        Text(sourceLabel)
            .font(StudioTheme.TypeScale.label.weight(.bold))
            .foregroundStyle(sourceTint)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(sourceTint.opacity(0.12))
            )
    }

    private var sourceLabel: String {
        item.displaySourceLabel
    }

    private var sourceTint: Color {
        switch item.sourceKind {
        case .keynote, .activeDeck:
            return StudioTheme.Tone.muted
        case .pptx:
            return StudioTheme.Tone.warn
        case .html:
            return StudioTheme.Tone.ready
        case .media:
            return item.isVideoMedia ? StudioTheme.Action.primary : StudioTheme.Action.primary
        case .agendaMarker:
            return StudioTheme.Tone.warn
        case .unsupported:
            return StudioTheme.textSecondary
        }
    }

    private func badge(text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(StudioTheme.TypeScale.label)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(background)
            )
    }
}
