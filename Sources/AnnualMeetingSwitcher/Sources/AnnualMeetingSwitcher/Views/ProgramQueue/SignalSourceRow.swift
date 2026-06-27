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

    private var rowStyle: SignalSourceRowStyleModel {
        SignalSourceRowStyleModel.make(
            queueRole: queueRole,
            isBroadcasting: isBroadcasting,
            isHovered: isHovered
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SignalSourceRowHeader(
                item: item,
                rowModel: rowModel,
                queueRole: queueRole,
                style: rowStyle,
                isBroadcasting: isBroadcasting,
                isPlaying: isPlaying,
                isSchedulePopoverPresented: $isSchedulePopoverPresented,
                onHandleDragChanged: onHandleDragChanged,
                onHandleDragEnded: onHandleDragEnded,
                onUpdateSchedule: onUpdateSchedule,
                onUpdateAgendaMarker: onUpdateAgendaMarker
            )

            SignalSourceRowStatusChips(
                item: item,
                rowModel: rowModel,
                queueRole: queueRole,
                isBroadcasting: isBroadcasting,
                rowContentIndent: rowContentIndent
            )

            if isSelected && rowModel.controlStyle != .none && rowModel.controlStyle != .unsupported {
                SignalSourceRowControlRail(
                    item: item,
                    rowModel: rowModel,
                    isHovered: isHovered,
                    controlTint: rowStyle.currentRowControlTint,
                    rowContentIndent: rowContentIndent,
                    onTogglePause: onTogglePause,
                    onEndHTML: onEndHTML,
                    onJumpToBeginning: onJumpToBeginning,
                    onSkipToEnd: onSkipToEnd,
                    onDelete: onDelete
                )
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
                rowStyle.backgroundFill
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: ProgramQueueRowFramePreferenceKey.self,
                            value: [item.id: proxy.frame(in: .global)]
                        )
                }
            }
        )
        .overlay(SignalSourceRowDropIndicator(manualDropPlacement: manualDropPlacement))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(rowStyle.borderColor, lineWidth: queueRole == .current ? 1.4 : 0.9)
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
}
