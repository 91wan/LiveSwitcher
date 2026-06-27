import SwiftUI

struct ProgramQueueList: View {
    let programItems: [ProgramItem]
    let currentProgramItem: ProgramItem?
    let isBroadcasting: Bool
    let isPlaying: Bool
    let mediaGeneration: Int
    let avCoordinator: AVPlayerCoordinator
    let programQueueDropPreview: ProgramQueueDropPreview?
    @Binding var programQueueRowFrames: [UUID: CGRect]
    @Binding var programQueueListFrame: CGRect
    let onSelect: (ProgramItem) -> Void
    let onTogglePause: (ProgramItem) -> Void
    let onEndHTML: () -> Void
    let onJumpToBeginning: (ProgramItem) -> Void
    let onSeekProgress: (Double, Int) -> Void
    let onSkipToEnd: (ProgramItem) -> Void
    let onUpdateSchedule: (ProgramItem, Date?, TimeInterval?) -> Void
    let onUpdateAgendaMarker: (ProgramItem, AgendaMarkerInput) -> Void
    let onDelete: (ProgramItem) -> Void
    let onDeleteOffsets: (IndexSet) -> Void
    let onHandleDragChanged: (UUID, CGPoint) -> Void
    let onHandleDragEnded: (UUID, CGPoint) -> Void

    var body: some View {
        let currentIndex = programItems.firstIndex { $0.id == currentProgramItem?.id }
        let nextPlayableIndex = ProgramQueueStore.nextPlayableIndexAfterCurrent(
            current: currentProgramItem,
            in: programItems
        )

        if programItems.isEmpty {
            EmptyView()
        } else {
            List {
                ForEach(Array(programItems.enumerated()), id: \.element.id) { index, item in
                    SignalSourceRow(
                        item: item,
                        queuePosition: index + 1,
                        queueRole: queueRole(for: index, currentIndex: currentIndex, nextPlayableIndex: nextPlayableIndex),
                        isSelected: currentProgramItem?.id == item.id,
                        isBroadcasting: isBroadcasting,
                        isPlaying: currentProgramItem?.id == item.id && isPlaying,
                        mediaGeneration: mediaGeneration,
                        avCoordinator: avCoordinator,
                        onSelect: { onSelect(item) },
                        onTogglePause: { onTogglePause(item) },
                        onEndHTML: onEndHTML,
                        onJumpToBeginning: { onJumpToBeginning(item) },
                        onSeekProgress: onSeekProgress,
                        onSkipToEnd: item.supportsSeeking ? { onSkipToEnd(item) } : nil,
                        onUpdateSchedule: { start, duration in onUpdateSchedule(item, start, duration) },
                        onUpdateAgendaMarker: { input in onUpdateAgendaMarker(item, input) },
                        onDelete: { onDelete(item) },
                        manualDropPlacement: programQueueDropPreview?.targetID == item.id ? programQueueDropPreview?.placement : nil,
                        onHandleDragChanged: { location in
                            onHandleDragChanged(item.id, location)
                        },
                        onHandleDragEnded: { location in
                            onHandleDragEnded(item.id, location)
                        }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHint("点击切换节目；拖拽左侧手柄调整顺序。")
                    .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onDelete(perform: onDeleteOffsets)
            }
            .listStyle(.plain)
            .onPreferenceChange(ProgramQueueRowFramePreferenceKey.self) { frames in
                programQueueRowFrames = frames
            }
            .onPreferenceChange(ProgramQueueListFramePreferenceKey.self) { frame in
                programQueueListFrame = frame
            }
            .frame(maxHeight: .infinity)
            .scrollContentBackground(.hidden)
            .background(
                GeometryReader { proxy in
                    StudioTheme.Surface.base.opacity(StudioTheme.Surface.Opacity.medium)
                        .preference(
                            key: ProgramQueueListFramePreferenceKey.self,
                            value: proxy.frame(in: .global)
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                    .stroke(StudioTheme.borderSubtle, lineWidth: 1)
            )
        }
    }

    private func queueRole(for index: Int, currentIndex: Int?, nextPlayableIndex: Int?) -> QueueRole {
        if currentIndex == index {
            return .current
        }
        return index == nextPlayableIndex ? .next : .queued
    }
}
