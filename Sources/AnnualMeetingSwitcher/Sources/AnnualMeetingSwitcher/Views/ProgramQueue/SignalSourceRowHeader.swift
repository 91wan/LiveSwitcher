import SwiftUI

struct SignalSourceRowHeader: View {
    let item: ProgramItem
    let rowModel: ProgramQueueRowModel
    let queueRole: QueueRole
    let style: SignalSourceRowStyleModel
    let isBroadcasting: Bool
    let isPlaying: Bool
    @Binding var isSchedulePopoverPresented: Bool
    let onHandleDragChanged: (CGPoint) -> Void
    let onHandleDragEnded: (CGPoint) -> Void
    let onUpdateSchedule: (Date?, TimeInterval?) -> Void
    let onUpdateAgendaMarker: (AgendaMarkerInput) -> Void

    var body: some View {
        HStack(spacing: 9) {
            ProgramQueueDragHandle(
                title: item.title,
                onDragChanged: onHandleDragChanged,
                onDragEnded: onHandleDragEnded
            )

            queueBadge

            ProgramThumbnailView(
                sourceURL: item.sourceURL,
                kind: item.sourceKind,
                isVideo: item.isVideoMedia,
                displaySize: CGSize(width: 48, height: 27)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(StudioTheme.TypeScale.body.weight(queueRole == .current ? .bold : .semibold))
                    .foregroundStyle(StudioTheme.textPrimary)
                    .lineLimit(1)
                    .help(item.title)

                Text(statusText)
                    .font(StudioTheme.TypeScale.label.weight(.semibold))
                    .foregroundStyle(style.statusTint)
                    .lineLimit(1)
            }
            .opacity(style.contentOpacity)
            .layoutPriority(1)

            Spacer(minLength: 0)

            scheduleButton

            PresentationReadinessDot(result: PresentationReadinessProbe.probe(item: item))
        }
    }

    private var queueBadge: some View {
        ProgramQueueNumberBadge(
            text: rowModel.queueBadgeText,
            kind: .setup,
            foreground: queueBadgeForeground,
            background: queueBadgeBackground
        )
    }

    private var queueBadgeForeground: Color {
        switch queueRole {
        case .current:
            return .white
        case .next:
            return StudioTheme.Tone.warn
        case .queued:
            return StudioTheme.textSecondary
        }
    }

    private var queueBadgeBackground: Color {
        switch queueRole {
        case .current:
            return isBroadcasting ? StudioTheme.Tone.live : StudioTheme.Action.primary
        case .next:
            return StudioTheme.Tone.warn.opacity(0.14)
        case .queued:
            return StudioTheme.Surface.raised
        }
    }

    private var scheduleButton: some View {
        Button {
            isSchedulePopoverPresented = true
        } label: {
            Label(
                item.isAgendaMarker ? "编辑" : scheduledTimeText,
                systemImage: item.isAgendaMarker ? "pencil" : (item.scheduledTimeText == nil ? "clock" : "clock.fill")
            )
                .labelStyle(.titleAndIcon)
                .font(StudioTheme.TypeScale.label.weight(.semibold))
                .foregroundStyle(item.scheduledTimeText == nil ? StudioTheme.textTertiary : StudioTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 7)
                .frame(height: 24)
                .background(
                    Capsule(style: .continuous)
                        .fill(StudioTheme.Surface.raised.opacity(0.8))
                )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(item.isAgendaMarker ? "编辑标记" : "设置议程开始时间和时长")
        .popover(isPresented: $isSchedulePopoverPresented, arrowEdge: .trailing) {
            if item.isAgendaMarker {
                AgendaMarkerEditorPopover(
                    mode: .edit,
                    initialInput: .fromMarker(item)
                ) { input in
                    onUpdateAgendaMarker(input)
                    isSchedulePopoverPresented = false
                }
            } else {
                AgendaScheduleEditorPopover(item: item) { start, duration in
                    onUpdateSchedule(start, duration)
                    isSchedulePopoverPresented = false
                }
            }
        }
    }

    private var scheduledTimeText: String {
        item.scheduledTimeText ?? "设时间"
    }

    private var statusText: String {
        switch queueRole {
        case .current:
            if item.sourceKind == .html {
                return isBroadcasting ? "当前大屏展示" : "当前预监源"
            }
            if [.keynote, .pptx, .activeDeck].contains(item.sourceKind) {
                return isBroadcasting ? "当前导播文稿" : "当前待播文稿"
            }
            return isPlaying ? "当前媒体播放中" : "当前已切入"
        case .next:
            return "下一条待播"
        case .queued:
            return "待播项目"
        }
    }
}
