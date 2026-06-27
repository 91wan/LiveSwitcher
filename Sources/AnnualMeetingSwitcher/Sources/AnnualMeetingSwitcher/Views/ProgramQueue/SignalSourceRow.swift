import SwiftUI

// MARK: - Queue Row

struct SignalSourceRow: View {
    let item: ProgramItem
    let queuePosition: Int
    let queueRole: QueueRole
    let isSelected: Bool
    let isBroadcasting: Bool
    let isPlaying: Bool
    let mediaGeneration: Int
    let avCoordinator: AVPlayerCoordinator
    let onSelect: () -> Void
    let onTogglePause: () -> Void
    let onEndHTML: () -> Void
    let onJumpToBeginning: () -> Void
    let onSeekProgress: (Double, Int) -> Void
    var onSkipToEnd: (() -> Void)? = nil
    var onUpdateSchedule: (Date?, TimeInterval?) -> Void = { _, _ in }
    var onUpdateAgendaMarker: (AgendaMarkerInput) -> Void = { _ in }
    let onDelete: () -> Void
    let manualDropPlacement: ProgramQueueDropPlacement?
    let onHandleDragChanged: (CGPoint) -> Void
    let onHandleDragEnded: (CGPoint) -> Void

    @State private var isHovered = false
    @State private var isSchedulePopoverPresented = false
    private let rowContentIndent: CGFloat = 124

    var rowModel: ProgramQueueRowModel {
        ProgramQueueRowModel(
            item: item,
            queuePosition: queuePosition,
            queueRole: queueRole,
            isBroadcasting: isBroadcasting,
            isPlaying: isPlaying
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                        .foregroundStyle(statusTint)
                        .lineLimit(1)
                }
                .opacity(contentOpacity)
                .layoutPriority(1)

                Spacer(minLength: 0)

                scheduleButton

                PresentationReadinessDot(result: PresentationReadinessProbe.probe(item: item))
            }

            HStack(spacing: 6) {
                stateBadge
                sourceTypeChip
                Spacer(minLength: 0)
            }
            .padding(.leading, rowContentIndent)
            .fixedSize(horizontal: false, vertical: true)

            if isSelected && rowModel.controlStyle != .none && rowModel.controlStyle != .unsupported {
                selectedControlRail
            }

            if isSelected && rowModel.showsProgressSlider {
                ProgressSliderRow(
                    avCoordinator: avCoordinator,
                    mediaGeneration: mediaGeneration,
                    onSeekProgress: onSeekProgress
                )
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .background(
            ZStack {
                backgroundFill
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: ProgramQueueRowFramePreferenceKey.self,
                            value: [item.id: proxy.frame(in: .global)]
                        )
                }
            }
        )
        .overlay(dropIndicatorOverlay)
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(borderColor, lineWidth: queueRole == .current ? 1.4 : 0.9)
        )
        .clipShape(RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
        .onTapGesture {
            guard !item.isAgendaMarker else { return }
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var dropIndicatorOverlay: some View {
        return VStack(spacing: 0) {
            dropIndicator(isActive: manualDropPlacement == .before)
            Spacer(minLength: 0)
            dropIndicator(isActive: manualDropPlacement == .after)
        }
        .padding(.horizontal, 6)
        .allowsHitTesting(false)
    }

    private func dropIndicator(isActive: Bool) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(StudioTheme.Action.primary)
            .frame(height: 3)
            .opacity(isActive ? 1 : 0)
            .shadow(color: StudioTheme.Action.primary.opacity(isActive ? 0.45 : 0), radius: 5)
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

    private var selectedControlRail: some View {
        HStack(spacing: 10) {
            Text(rowModel.controlRailLabel)
                .font(StudioTheme.TypeScale.label)
                .foregroundStyle(currentRowControlTint)
                .lineLimit(1)

            HStack(spacing: 7) {
                switch rowModel.controlStyle {
                case .media:
                    controlButton(
                        systemName: rowModel.primarySystemName,
                        accessibilityLabel: rowModel.primaryAccessibilityLabel,
                        tint: .white,
                        fill: currentRowControlTint,
                        action: onTogglePause
                    )
                    .help(rowModel.primaryHelp)

                    controlButton(
                        systemName: "backward.end.fill",
                        accessibilityLabel: "跳回当前节目开头",
                        tint: currentRowControlTint,
                        fill: currentRowControlTint.opacity(0.12),
                        action: onJumpToBeginning
                    )
                    .help("跳回开头")

                    if let onSkipToEnd {
                        controlButton(
                            systemName: "forward.end.fill",
                            accessibilityLabel: "跳到当前节目结尾",
                            tint: currentRowControlTint,
                            fill: currentRowControlTint.opacity(0.12),
                            action: onSkipToEnd
                        )
                        .help("跳至结束")
                    }
                case .html:
                    controlButton(
                        systemName: rowModel.primarySystemName,
                        accessibilityLabel: rowModel.primaryAccessibilityLabel,
                        tint: .white,
                        fill: currentRowControlTint,
                        action: onEndHTML
                    )
                    .help(rowModel.primaryHelp)
                case .presentation:
                    controlButton(
                        systemName: rowModel.primarySystemName,
                        accessibilityLabel: rowModel.primaryAccessibilityLabel,
                        tint: .white,
                        fill: currentRowControlTint,
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

    private var backgroundFill: Color {
        switch queueRole {
        case .current:
            return (isBroadcasting ? StudioTheme.Tone.live : StudioTheme.Action.primary).opacity(0.08)
        case .next:
            return StudioTheme.Tone.warn.opacity(isHovered ? 0.11 : 0.07)
        case .queued:
            return isHovered ? StudioTheme.Surface.raised.opacity(0.8) : Color.clear
        }
    }

    private var borderColor: Color {
        switch queueRole {
        case .current:
            return isBroadcasting ? StudioTheme.borderCritical : StudioTheme.borderActive
        case .next:
            return StudioTheme.Tone.warn.opacity(0.24)
        case .queued:
            return isHovered ? StudioTheme.borderSubtle : Color.clear
        }
    }

    private var sourceLabel: String {
        item.displaySourceLabel
    }

    private var currentRowControlTint: Color {
        isBroadcasting ? StudioTheme.Tone.live : StudioTheme.Action.primary
    }

    private var contentOpacity: Double {
        switch queueRole {
        case .current:
            return 1
        case .next:
            return 0.96
        case .queued:
            return 0.82
        }
    }

    private var statusTint: Color {
        switch queueRole {
        case .current:
            return .secondary
        case .next:
            return StudioTheme.Tone.warn
        case .queued:
            return .secondary
        }
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

    private func iconName(for item: ProgramItem) -> String {
        switch item.sourceKind {
        case .keynote, .activeDeck:
            return "play.rectangle.fill"
        case .pptx:
            return "doc.richtext"
        case .html:
            return "globe"
        case .media:
            return item.isVideoMedia ? "film" : "music.note"
        case .agendaMarker:
            return "mappin.and.ellipse"
        case .unsupported:
            return "doc.fill"
        }
    }
}
