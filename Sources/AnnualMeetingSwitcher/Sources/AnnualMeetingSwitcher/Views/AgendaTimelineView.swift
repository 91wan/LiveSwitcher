import SwiftUI

struct AgendaTimelineView: View {
    let items: [ProgramItem]
    let currentItemID: UUID?
    let isBroadcasting: Bool
    let onSelect: (ProgramItem) -> Void
    let onUpdateSchedule: (ProgramItem, Date?, TimeInterval?) -> Void
    let onUpdateAgendaMarker: (ProgramItem, AgendaMarkerInput) -> Void
    let onDelete: (ProgramItem) -> Void

    private var model: AgendaTimelineModel {
        AgendaTimelineModel.make(items: items, dayAnchor: Date())
    }

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.entries) { entry in
                            AgendaTimelineRow(
                                entry: entry,
                                isCurrent: entry.id == currentItemID,
                                isBroadcasting: isBroadcasting,
                                onSelect: { onSelect(entry.item) },
                                onUpdateSchedule: { start, duration in
                                    onUpdateSchedule(entry.item, start, duration)
                                },
                                onUpdateAgendaMarker: { input in
                                    onUpdateAgendaMarker(entry.item, input)
                                },
                                onDelete: { onDelete(entry.item) }
                            )
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: .infinity)
                .background(StudioTheme.Surface.base.opacity(StudioTheme.Surface.Opacity.medium))
                .clipShape(RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                        .stroke(StudioTheme.borderSubtle, lineWidth: 1)
                )
            }
        }
        .accessibilityLabel("议程时间线")
    }
}

private struct AgendaTimelineRow: View {
    let entry: AgendaTimelineEntry
    let isCurrent: Bool
    let isBroadcasting: Bool
    let onSelect: () -> Void
    let onUpdateSchedule: (Date?, TimeInterval?) -> Void
    let onUpdateAgendaMarker: (AgendaMarkerInput) -> Void
    let onDelete: () -> Void

    @State private var isSchedulePopoverPresented = false

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            VStack(spacing: 4) {
                Text(entry.timeRangeText)
                    .font(StudioTheme.TypeScale.label.weight(.bold))
                    .foregroundStyle(entry.isStartInferred ? StudioTheme.textTertiary : StudioTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Rectangle()
                    .fill(StudioTheme.borderSubtle)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 58)

            timelineBody

            Button {
                isSchedulePopoverPresented = true
            } label: {
                Image(systemName: entry.item.isAgendaMarker ? "pencil" : "clock")
                    .font(StudioTheme.TypeScale.caption.weight(.bold))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help(entry.item.isAgendaMarker ? "编辑标记" : "编辑议程时间")
            .popover(isPresented: $isSchedulePopoverPresented, arrowEdge: .trailing) {
                if entry.item.isAgendaMarker {
                    AgendaMarkerEditorPopover(
                        mode: .edit,
                        initialInput: .fromMarker(entry.item)
                    ) { input in
                        onUpdateAgendaMarker(input)
                        isSchedulePopoverPresented = false
                    }
                } else {
                    AgendaScheduleEditorPopover(item: entry.item) { start, duration in
                        onUpdateSchedule(start, duration)
                        isSchedulePopoverPresented = false
                    }
                }
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(StudioTheme.TypeScale.caption.weight(.bold))
                    .foregroundStyle(StudioTheme.Action.danger)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("删除议程项")
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(isCurrent ? tint.opacity(0.55) : StudioTheme.borderSubtle, lineWidth: isCurrent ? 1.3 : 1)
        )
    }

    @ViewBuilder
    private var timelineBody: some View {
        if entry.item.isAgendaMarker {
            timelineBodyContent
        } else {
            Button(action: onSelect) {
                timelineBodyContent
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var timelineBodyContent: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.item.isAgendaMarker ? "mappin.and.ellipse" : "play.rectangle")
                .font(StudioTheme.TypeScale.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(tint.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(StudioTheme.TypeScale.caption.weight(.bold))
                    .foregroundStyle(StudioTheme.textPrimary)
                    .lineLimit(1)
                Text(entry.item.isAgendaMarker ? "标记 · \(entry.durationMinutes) 分钟" : "\(entry.item.displaySourceLabel) · \(entry.durationMinutes) 分钟")
                    .font(StudioTheme.TypeScale.label.weight(.semibold))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            if isCurrent {
                StatusBadge(isBroadcasting ? "直播" : "当前", kind: isBroadcasting ? .live : .ready)
            }
        }
    }

    private var tint: Color {
        if isCurrent {
            return isBroadcasting ? StudioTheme.Tone.live : StudioTheme.Action.primary
        }
        if entry.item.isAgendaMarker {
            return StudioTheme.Tone.warn
        }
        return StudioTheme.textSecondary
    }

    private var background: Color {
        if isCurrent {
            return tint.opacity(0.08)
        }
        if entry.item.isAgendaMarker {
            return StudioTheme.Tone.warn.opacity(0.07)
        }
        return StudioTheme.Surface.raised.opacity(0.72)
    }
}
