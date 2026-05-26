import SwiftUI
import UniformTypeIdentifiers

// MARK: - 左侧信号源面板

struct LeftPanel: View {
    @EnvironmentObject var viewModel: SwitcherViewModel
    @State private var isDraggingOver = false

    var body: some View {
        VStack(spacing: 10) {
            headerRow
            autoPlayOptionRow
            presentationReadinessSummaryRow
            agendaControlRow

            dropZone

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
                    onDelete: { item in viewModel.removeProgramItem(withID: item.id) }
                )
            } else {
                sourceList
            }

            Spacer(minLength: 0)

            queueFooter
        }
        .padding(16)
        .frame(width: StudioTheme.directorRailWidth)
        .studioCard(cornerRadius: 28)
        // ── 键盘快捷键 1-9 绑定 ──
        .background(ShortcutKeyHandler(viewModel: viewModel))
    }

    private var agendaControlRow: some View {
        HStack(spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(StudioTheme.TypeScale.label.weight(.bold))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .accessibilityHidden(true)
                Text("时间线")
                    .font(StudioTheme.TypeScale.label.weight(.semibold))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(width: 48, alignment: .leading)
                Toggle("", isOn: $viewModel.showAgendaTimeline)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            .help("将节目单显示为议程时间线，可选显示计划时间。")

            Spacer(minLength: 0)

            Toggle(isOn: $viewModel.autoAdvanceAtScheduledTime) {
                Image(systemName: "clock.badge.checkmark")
                    .font(StudioTheme.TypeScale.caption.weight(.bold))
                    .foregroundStyle(StudioTheme.textSecondary)
            }
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .help("下一项到达计划开始时间时提示；不会自动切换。")

            Button {
                viewModel.addAgendaMarker()
            } label: {
                Label("标记", systemImage: "mappin.and.ellipse")
                    .font(StudioTheme.TypeScale.caption.weight(.bold))
                    .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .focusable(false)
            .help("添加茶歇、转场等不可播放的议程标记。")
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }

    private var autoPlayOptionRow: some View {
        let model = AutoNextVideoControlModel.make(
            isEnabled: viewModel.autoPlayNextVideoOnEnd,
            hasCurrentProgram: viewModel.currentProgramItem != nil
        )

        return Toggle(isOn: $viewModel.autoPlayNextVideoOnEnd) {
            HStack(spacing: 7) {
                Image(systemName: model.systemImage)
                    .font(StudioTheme.TypeScale.caption.weight(.bold))
                    .foregroundStyle(StudioTheme.color(for: model.statusKind))
                Text("视频播毕自动下一条")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .toggleStyle(.switch)
        .tint(StudioTheme.Tone.warn)
        .controlSize(.small)
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .help("仅当前节目播毕且下一条也是视频时自动播放；不会自动打开 HTML、PPT 或 Keynote。")
    }

    @ViewBuilder
    private var presentationReadinessSummaryRow: some View {
        let summary = PresentationReadinessSummary.make(items: viewModel.programItems)
        if summary.hasPresentationItems {
            HStack(spacing: 7) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(StudioTheme.TypeScale.caption.weight(.bold))
                    .foregroundStyle(StudioTheme.color(for: summary.statusKind))
                Text("演示就绪")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                StatusBadge(summary.displayText, kind: summary.statusKind)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                    .fill(StudioTheme.Surface.raised.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                    .stroke(StudioTheme.borderSubtle, lineWidth: 1)
            )
            .help("切换前检查 PPTX / Keynote 就绪状态。")
        }
    }

    // MARK: - 标题行

    private var headerRow: some View {
        let programCount = viewModel.programItems.count

        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("节目单")
                    .font(StudioTheme.title())
                    .foregroundStyle(StudioTheme.textPrimary)
                Text("\(programCount) 个节目")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textSecondary)
            }
            Spacer()
            if CountPillVisibilityPolicy.shouldShow(count: programCount) {
                CountPill("\(programCount)", kind: .ready)
            }
            Button(action: { viewModel.scanAndAddKeynoteWindows() }) {
                Image(systemName: "arrow.clockwise")
                    .font(StudioTheme.TypeScale.body.weight(.bold))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                            .fill(StudioTheme.Surface.raised)
                    )
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("刷新 / 重新扫描 Keynote")
            .accessibilityLabel("刷新 Keynote 信号源")
        }
    }

    // MARK: - 拖拽放入框

    private var dropZone: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                addSourceButton(title: "视频 / 音频", systemName: "film.fill") {
                    openFilePicker(types: [.movie, .audio])
                }
                addSourceButton(title: "HTML", systemName: "globe.asia.australia.fill") {
                    openHTMLPicker()
                }
            }

            HStack(spacing: 8) {
                addSourceButton(title: "PPTX", systemName: "doc.richtext.fill") {
                    openPPTXPicker()
                }
                addSourceButton(title: "Keynote", systemName: "play.rectangle.fill") {
                    openKeynotePicker()
                }
            }

            Text("拖入文件")
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textTertiary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)

            Text("或使用上方按钮添加")
                .font(StudioTheme.TypeScale.label.weight(.medium))
                .foregroundStyle(StudioTheme.textTertiary.opacity(0.82))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .fill(StudioTheme.Surface.base)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(isDraggingOver ? StudioTheme.borderActive : StudioTheme.borderSubtle, lineWidth: 1)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
            handleDrop(providers: providers)
        }
    }

    private func addSourceButton(
        title: String,
        systemName: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(StudioTheme.TypeScale.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .focusable(false)
    }

    // MARK: - 已添加信号源列表（Issue #10: 显示拖拽排序手柄）

    @ViewBuilder
    private var sourceList: some View {
        let currentIndex = viewModel.programItems.firstIndex { $0.id == viewModel.currentProgramItem?.id }
        let nextPlayableIndex = ProgramQueueStore.nextPlayableIndexAfterCurrent(
            current: viewModel.currentProgramItem,
            in: viewModel.programItems
        )

        if viewModel.programItems.isEmpty {
            EmptyView()
        } else {
            List {
                ForEach(Array(viewModel.programItems.enumerated()), id: \.element.id) { index, item in
                    SignalSourceRow(
                        item: item,
                        queuePosition: index + 1,
                        queueRole: queueRole(for: index, currentIndex: currentIndex, nextPlayableIndex: nextPlayableIndex),
                        isSelected: viewModel.currentProgramItem?.id == item.id,
                        isBroadcasting: viewModel.isBroadcasting,
                        isPlaying: viewModel.currentProgramItem?.id == item.id && viewModel.avCoordinator.isPlaying,
                        avCoordinator: viewModel.avCoordinator,
                        onSelect: { viewModel.switchToProgramAfterReadinessConfirmation(item) },
                        onTogglePause: { viewModel.togglePause(for: item) },
                        onEndHTML: { viewModel.endHTMLPresentation() },
                        onJumpToBeginning: { viewModel.seekProgramItemToStart(item) },
                        onSkipToEnd: item.supportsSeeking ? { viewModel.seekProgramItemToEnd(item) } : nil,
                        onUpdateSchedule: { start, duration in
                            viewModel.updateProgramItemSchedule(
                                id: item.id,
                                scheduledStartAt: start,
                                scheduledDuration: duration
                            )
                        },
                        onDelete: { viewModel.removeProgramItem(withID: item.id) }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHint("拖拽调整顺序。")
                    .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onMove { from, to in
                    viewModel.moveProgramItems(from: from, to: to)
                }
                .onDelete { indexSet in
                    indexSet.forEach { viewModel.removeProgramItem(withID: viewModel.programItems[$0].id) }
                }
            }
            .listStyle(.plain)
            .frame(maxHeight: .infinity)
            .scrollContentBackground(.hidden)
            .background(StudioTheme.Surface.base.opacity(StudioTheme.Surface.Opacity.medium))
            .clipShape(RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                    .stroke(StudioTheme.borderSubtle, lineWidth: 1)
            )
        }
    }

    private var queueFooter: some View {
        let currentTitle = viewModel.currentProgramItem?.title ?? "未选中"

        return Text("共 \(viewModel.programItems.count) 个节目 · \(currentTitle)")
            .font(StudioTheme.caption())
            .foregroundStyle(StudioTheme.textTertiary)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .accessibilityLabel("节目单底部。\(viewModel.programItems.count) 个节目。当前 \(currentTitle)。")
    }

    private func queueRole(for index: Int, currentIndex: Int?, nextPlayableIndex: Int?) -> QueueRole {
        if currentIndex == index {
            return .current
        }
        return index == nextPlayableIndex ? .next : .queued
    }
    // MARK: - 文件选择

    private func openFilePicker(types: [UTType]) {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.title = "选择媒体文件"
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            panel.allowedContentTypes = types

            guard panel.runModal() == .OK else { return }
            let items = panel.urls.map { url in
                ProgramItem(
                    title: url.deletingPathExtension().lastPathComponent,
                    subtitle: url.pathExtension.uppercased(),
                    sourceURL: url
                )
            }
            viewModel.addProgramItems(items)
        }
    }

    // HTML 文件选择（添加到播放列表，推送到大屏 WKWebView 展示）
    private func openHTMLPicker() {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.title = "选择 HTML 文件"
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            panel.allowedContentTypes = [UTType.html]

            guard panel.runModal() == .OK else { return }
            let items = panel.urls.map { url in
                ProgramItem(
                    title: url.deletingPathExtension().lastPathComponent,
                    subtitle: "HTML",
                    sourceURL: url
                )
            }
            viewModel.addProgramItems(items)
        }
    }

    // V21 Fix #5: PPTX 纯入列 - 只添加到播放列表，不立即唤醒 WPS
    private func openPPTXPicker() {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.title = "选择 PPTX 文件"
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            let pptxType = UTType("org.openxmlformats.presentationml.presentation") ?? .data
            panel.allowedContentTypes = [pptxType]

            guard panel.runModal() == .OK else { return }
            let items = panel.urls.map { url in
                // V21 Fix #5: 只添加到列表，点击"播放"时才唤醒 WPS
                ProgramItem(
                    title: url.deletingPathExtension().lastPathComponent,
                    subtitle: "PPTX",
                    sourceURL: url
                )
            }
            viewModel.addProgramItems(items)
        }
    }

    private func openKeynotePicker() {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.title = "选择 Keynote 文件"
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            panel.allowedContentTypes = [
                UTType("com.apple.iWork.Keynote.key"),
                UTType("com.apple.keynote.key")
            ].compactMap { $0 }
            if panel.allowedContentTypes.isEmpty {
                panel.allowedContentTypes = [.data]
            }

            guard panel.runModal() == .OK else { return }
            let items = panel.urls.compactMap { url -> ProgramItem? in
                let ext = url.pathExtension.lowercased()
                guard ext == "key" || ext == "keynote" else { return nil }
                return ProgramItem(
                    title: url.deletingPathExtension().lastPathComponent,
                    subtitle: "KEY",
                    sourceURL: url
                )
            }
            viewModel.addProgramItems(items)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var didRequestImport = false

        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else {
                continue
            }
            didRequestImport = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let url = FileDropSupport.decodeFileURL(from: item),
                      let programItem = FileDropSupport.importableProgramItem(from: url) else { return }
                DispatchQueue.main.async {
                    viewModel.addProgramItem(programItem)
                }
            }
        }
        return didRequestImport
    }
}

// MARK: - 键盘快捷键处理：透明 View 嵌入主 Stack，绑定 1-9

struct ShortcutKeyHandler: View {
    @ObservedObject var viewModel: SwitcherViewModel

    var body: some View {
        ZStack {
            ForEach(1...9, id: \.self) { index in
                Button("") {
                    viewModel.switchToProgram(at: index - 1)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index)")), modifiers: [])
                .accessibilityHidden(true)
                .opacity(0)
                .frame(width: 0, height: 0)
            }
        }
        .frame(width: 0, height: 0)
        .hidden()
    }
}

struct SecondaryImportButtonStyle: ButtonStyle {
    var role: StudioTheme.StatusKind = .idle

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(StudioTheme.TypeScale.body.weight(.bold))
            .lineLimit(1)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: StudioTheme.controlHeightM)
            .background(
                RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.16 : 0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            )
    }

    private var tint: Color {
        switch role {
        case .warn:
            return StudioTheme.Tone.warn
        case .fail, .live:
            return StudioTheme.Tone.fail
        default:
            return StudioTheme.Action.primary
        }
    }
}

// MARK: - Preview

#Preview {
    LeftPanel()
        .environmentObject({
            let vm = SwitcherViewModel()
            vm.programItems = [
                ProgramItem(title: "开场视频", subtitle: "MP4"),
                ProgramItem(title: "年终PPT", subtitle: "KEY"),
            ]
            return vm
        }())
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
}
