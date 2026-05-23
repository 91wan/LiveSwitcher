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

            dropZone

            sourceList

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: StudioTheme.directorRailWidth)
        .studioCard(cornerRadius: 28)
        // ── 键盘快捷键 1-9 绑定 ──
        .background(ShortcutKeyHandler(viewModel: viewModel))
    }

    private var autoPlayOptionRow: some View {
        Toggle(isOn: $viewModel.autoPlayNextVideoOnEnd) {
            HStack(spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(StudioTheme.statusWarn)
                Text("Auto-next video")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        .help("仅当前节目播毕且下一条也是视频时自动播放；不会自动打开 HTML、PPT 或 Keynote。")
    }

    // MARK: - 标题行

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Run Queue")
                    .font(StudioTheme.title())
                    .foregroundStyle(StudioTheme.textPrimary)
                Text("\(viewModel.programItems.count) 个节目")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textSecondary)
            }
            Spacer()
            CountPill("\(viewModel.programItems.count)", kind: viewModel.programItems.isEmpty ? .idle : .ready)
            Button(action: { viewModel.scanAndAddKeynoteWindows() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                            .fill(StudioTheme.surfaceSecondary)
                    )
            }
            .buttonStyle(.plain)
            .help("刷新 / 重新扫描 Keynote")
        }
    }

    // MARK: - 拖拽放入框

    private var dropZone: some View {
        HStack(spacing: 10) {
            Menu {
                Button {
                    openFilePicker(types: [.movie, .audio])
                } label: {
                    Label("Video / Audio", systemImage: "film.fill")
                }

                Button {
                    openHTMLPicker()
                } label: {
                    Label("HTML", systemImage: "globe.asia.australia.fill")
                }

                Button {
                    openPPTXPicker()
                } label: {
                    Label("PPTX", systemImage: "doc.richtext.fill")
                }

                Button {
                    openKeynotePicker()
                } label: {
                    Label("Keynote", systemImage: "play.rectangle.fill")
                }
            } label: {
                Label("Add Source", systemImage: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: StudioTheme.controlHeightM)
            }
            .menuStyle(.button)
            .buttonStyle(.borderedProminent)

            Text("Drag files here")
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textTertiary)
                .lineLimit(1)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .fill(StudioTheme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(isDraggingOver ? StudioTheme.borderActive : StudioTheme.borderSubtle, lineWidth: 1)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
            handleDrop(providers: providers)
        }
    }

    // MARK: - 已添加信号源列表（Issue #10: 显示拖拽排序手柄）

    private var sourceList: some View {
        let currentIndex = viewModel.programItems.firstIndex { $0.id == viewModel.currentProgramItem?.id }

        guard !viewModel.programItems.isEmpty else {
            return AnyView(
                EmptyStateView(
                    title: "No sources queued",
                    message: "Add or drag in video, audio, PPTX, Keynote, or HTML sources before switching.",
                    systemImage: "rectangle.stack.badge.plus"
                )
                .frame(maxHeight: 190)
            )
        }

        return AnyView(List {
            ForEach(Array(viewModel.programItems.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 6) {
                    // Issue #10: 显式排序手柄图标
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(StudioTheme.textTertiary)
                        .frame(width: 20)
                        .help("拖动此图标可排序")

                    SignalSourceRow(
                        item: item,
                        queuePosition: index + 1,
                        queueRole: queueRole(for: index, currentIndex: currentIndex),
                        isSelected: viewModel.currentProgramItem?.id == item.id,
                        isBroadcasting: viewModel.isBroadcasting,
                        isPlaying: viewModel.currentProgramItem?.id == item.id && viewModel.avCoordinator.isPlaying,
                        avCoordinator: viewModel.avCoordinator,
                        onSelect: { viewModel.switchToProgram(item) },
                        onTogglePause: { viewModel.togglePause(for: item) },
                        onEndHTML: { viewModel.endHTMLPresentation() },
                        onJumpToBeginning: { viewModel.seekProgramItemToStart(item) },
                        onSkipToEnd: item.supportsSeeking ? { viewModel.seekProgramItemToEnd(item) } : nil,
                        onDelete: { viewModel.removeProgramItem(withID: item.id) }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
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
        .background(StudioTheme.surfacePrimary.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        ))
    }

    private var nextProgramItem: ProgramItem? {
        guard !viewModel.programItems.isEmpty else { return nil }
        guard let currentID = viewModel.currentProgramItem?.id,
              let currentIndex = viewModel.programItems.firstIndex(where: { $0.id == currentID })
        else {
            return viewModel.programItems.first
        }
        let nextIndex = viewModel.programItems.index(after: currentIndex)
        guard nextIndex < viewModel.programItems.endIndex else { return nil }
        return viewModel.programItems[nextIndex]
    }

    private func queueRole(for index: Int, currentIndex: Int?) -> QueueRole {
        if currentIndex == index {
            return .current
        }
        if let currentIndex {
            return index == currentIndex + 1 ? .next : .queued
        }
        return index == 0 ? .next : .queued
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
            for url in panel.urls {
                let item = ProgramItem(
                    title: url.deletingPathExtension().lastPathComponent,
                    subtitle: url.pathExtension.uppercased(),
                    sourceURL: url
                )
                viewModel.addProgramItem(item)
            }
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
            for url in panel.urls {
                let item = ProgramItem(
                    title: url.deletingPathExtension().lastPathComponent,
                    subtitle: "HTML",
                    sourceURL: url
                )
                viewModel.addProgramItem(item)
            }
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
            for url in panel.urls {
                // V21 Fix #5: 只添加到列表，点击"播放"时才唤醒 WPS
                let item = ProgramItem(
                    title: url.deletingPathExtension().lastPathComponent,
                    subtitle: "PPTX",
                    sourceURL: url
                )
                viewModel.addProgramItem(item)
            }
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
            for url in panel.urls {
                let ext = url.pathExtension.lowercased()
                guard ext == "key" || ext == "keynote" else { continue }
                let item = ProgramItem(
                    title: url.deletingPathExtension().lastPathComponent,
                    subtitle: "KEY",
                    sourceURL: url
                )
                viewModel.addProgramItem(item)
            }
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
            .font(.system(size: 13, weight: .bold))
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
            return StudioTheme.statusWarn
        case .fail, .live:
            return StudioTheme.statusFail
        default:
            return StudioTheme.actionPrimary
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
