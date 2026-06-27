import SwiftUI

@MainActor
struct LeftPanel: View {
    @Environment(SwitcherViewModel.self) var viewModel
    @State private var isDraggingOver = false
    @State private var programQueueRowFrames: [UUID: CGRect] = [:]
    @State private var programQueueListFrame: CGRect = .null
    @State private var programQueueDropPreview: ProgramQueueDropPreview?
    @State private var isAgendaMarkerPopoverPresented = false

    var body: some View {
        @Bindable var viewModel = viewModel

        return SetupSideRailChrome(
            footer: {
                ProgramRailFooter(
                    programCount: viewModel.programItems.count,
                    currentTitle: viewModel.currentProgramItem?.title ?? "未选中"
                )
            }
        ) {
            VStack(spacing: SetupSideRailLayoutMetrics.contentSpacing) {
                ProgramRailHeader(
                    programCount: viewModel.programItems.count,
                    onRefreshKeynote: { viewModel.scanAndAddKeynoteWindows() }
                )

                ProgramAutoPlayOptionRow(
                    isEnabled: $viewModel.autoPlayNextVideoOnEnd,
                    hasCurrentProgram: viewModel.currentProgramItem != nil
                )

                ProgramAgendaControlRow(
                    showAgendaTimeline: $viewModel.showAgendaTimeline,
                    isAgendaTimeReminderEnabled: $viewModel.isAgendaTimeReminderEnabled,
                    isAgendaMarkerPopoverPresented: $isAgendaMarkerPopoverPresented,
                    onAddAgendaMarker: { input in viewModel.addAgendaMarker(input) }
                )

                ProgramImportDropZone(
                    isDraggingOver: $isDraggingOver,
                    onAddProgramItems: { viewModel.addProgramItems($0) },
                    onAddProgramItem: { viewModel.addProgramItem($0) }
                )

                if viewModel.showAgendaTimeline {
                    AgendaTimelineView(
                        items: viewModel.programItems,
                        currentItemID: viewModel.currentProgramItem?.id,
                        isBroadcasting: viewModel.isBroadcasting,
                        onSelect: { item in viewModel.switchToProgramAfterReadinessConfirmation(item) },
                        onUpdateSchedule: { item, start, duration in
                            viewModel.updateProgramItemSchedule(
                                id: item.id,
                                scheduledStartAt: start,
                                scheduledDuration: duration
                            )
                        },
                        onUpdateAgendaMarker: { item, input in
                            viewModel.updateAgendaMarker(id: item.id, input: input)
                        },
                        onDelete: { item in viewModel.removeProgramItem(withID: item.id) }
                    )
                } else {
                    ProgramQueueList(
                        programItems: viewModel.programItems,
                        currentProgramItem: viewModel.currentProgramItem,
                        isBroadcasting: viewModel.isBroadcasting,
                        isPlaying: viewModel.avCoordinator.isPlaying,
                        mediaGeneration: viewModel.runtime.state.media.generation,
                        avCoordinator: viewModel.avCoordinator,
                        programQueueDropPreview: programQueueDropPreview,
                        programQueueRowFrames: $programQueueRowFrames,
                        programQueueListFrame: $programQueueListFrame,
                        onSelect: { viewModel.switchToProgramAfterReadinessConfirmation($0) },
                        onTogglePause: { viewModel.togglePause(for: $0) },
                        onEndHTML: { viewModel.endHTMLPresentation() },
                        onJumpToBeginning: { viewModel.seekProgramItemToStart($0) },
                        onSeekProgress: { progress, generation in
                            viewModel.seekCurrentMedia(toProgress: progress, expectedGeneration: generation)
                        },
                        onSkipToEnd: { viewModel.seekProgramItemToEnd($0) },
                        onUpdateSchedule: { item, start, duration in
                            viewModel.updateProgramItemSchedule(
                                id: item.id,
                                scheduledStartAt: start,
                                scheduledDuration: duration
                            )
                        },
                        onUpdateAgendaMarker: { item, input in
                            viewModel.updateAgendaMarker(id: item.id, input: input)
                        },
                        onDelete: { viewModel.removeProgramItem(withID: $0.id) },
                        onDeleteOffsets: { indexSet in viewModel.removeProgramItems(at: indexSet) },
                        onHandleDragChanged: updateProgramQueueDrag,
                        onHandleDragEnded: finishProgramQueueDrag
                    )
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private func updateProgramQueueDrag(draggedID: UUID, location: CGPoint) {
        programQueueDropPreview = programQueueDropTarget(at: location, excluding: draggedID)
    }

    private func finishProgramQueueDrag(draggedID: UUID, location: CGPoint) {
        defer {
            programQueueDropPreview = nil
        }
        guard let target = programQueueDropTarget(at: location, excluding: draggedID) else {
            return
        }
        _ = viewModel.moveProgramItem(
            draggedID: draggedID,
            targetID: target.targetID,
            placement: target.placement
        )
    }

    private func programQueueDropTarget(at location: CGPoint, excluding draggedID: UUID) -> ProgramQueueDropPreview? {
        ProgramQueueDropTargetResolver.resolve(
            location: location,
            draggedID: draggedID,
            rowFrames: programQueueRowFrames,
            listFrame: programQueueListFrame
        )
    }
}

#Preview {
    LeftPanel()
        .environment({
            let vm = SwitcherViewModel()
            vm.applyProgramQueueProjectionFromRuntime([
                ProgramItem(title: "开场视频", subtitle: "MP4"),
                ProgramItem(title: "年终PPT", subtitle: "KEY"),
            ])
            return vm
        }())
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
}
