import SwiftUI
import UniformTypeIdentifiers

// MARK: - 左侧信号源面板

struct LeftPanel: View {
    @EnvironmentObject var viewModel: SwitcherViewModel
    @State private var isDraggingOver = false

    var body: some View {
        VStack(spacing: 10) {
            // ── 标题行（Issue #3: 改叫"播放列表"）──
            headerRow
            autoPlayOptionRow

            // ── 拖拽放入大框 ──
            dropZone

            sourceList

            // ── Bug5修复：HTML播放中显示"结束展示"按钮 ──
            if viewModel.currentHTMLURL != nil {
                Button(action: {
                    viewModel.endHTMLPresentation()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("结束 HTML 展示 · 回到壁纸")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                            .fill(StudioTheme.actionDanger)
                    )
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }

            Spacer(minLength: 0)

            // ── 输出屏幕模块（Issue #10: 超大胶囊框 .title2）──
            outputScreenModule
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
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(StudioTheme.actionPrimary)
                Text("播毕自动下一条视频")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textPrimary)
                    .lineLimit(1)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .fill(StudioTheme.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
        .help("仅当前节目播毕且下一条也是视频时自动播放；不会自动打开 HTML、PPT 或 Keynote。")
    }

    // MARK: - 标题行

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("播放队列")
                    .font(StudioTheme.title())
                    .foregroundStyle(StudioTheme.textPrimary)
                Text("\(viewModel.programItems.count) 个节目")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textSecondary)
                Text(queueHeaderSummary)
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textTertiary)
                    .lineLimit(2)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ADD SOURCE")
                    .font(StudioTheme.statusLabel())
                    .foregroundStyle(StudioTheme.textSecondary)
                Spacer()
                Text("VIDEO / AUDIO / PPTX / HTML")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(StudioTheme.textTertiary)
            }
            HStack(spacing: 8) {
                Button {
                    openFilePicker(types: [.movie, .audio])
                } label: {
                    Label("选择视频", systemImage: "film.fill")
                }
                .buttonStyle(SecondaryImportButtonStyle())

                Button {
                    openPPTXPicker()
                } label: {
                    Label("选择 PPTX", systemImage: "doc.richtext.fill")
                }
                .buttonStyle(SecondaryImportButtonStyle(role: .warn))
            }

            Button {
                openHTMLPicker()
            } label: {
                Label("选择 HTML（大屏展示）", systemImage: "globe.asia.australia.fill")
            }
            .buttonStyle(SecondaryImportButtonStyle())
            .frame(maxWidth: .infinity)

            Text("可拖入本地媒体、PPTX 或 HTML 文件；不支持的文件会被忽略。")
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textTertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
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
        .frame(maxHeight: 300)
        .scrollContentBackground(.hidden)
        .background(StudioTheme.surfacePrimary.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        ))
    }

    private var queueHeaderSummary: String {
        let current = viewModel.currentProgramItem?.title ?? "No current"
        let next = nextProgramItem?.title ?? "No next"
        return "Current: \(current) · Next: \(next)"
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




    // MARK: - 输出屏幕模块（Issue #10: 超大胶囊按钮）

    private var outputScreenModule: some View {
        let model = ProjectionButtonModel.make(
            isBroadcasting: viewModel.isBroadcasting,
            hasExternalDisplay: viewModel.hasExternalDisplay,
            safetyNotice: viewModel.broadcastSafetyNotice
        )

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("输出屏幕")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(StudioTheme.textSecondary)
                    HStack(spacing: 6) {
                        Image(systemName: model.screenSystemImage)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(StudioTheme.textSecondary)
                        Text(model.screenLabel)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(StudioTheme.textPrimary)
                    }
                }
                Spacer()
                StatusBadge(
                    model.statusText,
                    kind: model.statusKind
                )
            }

            Button(action: { viewModel.handleSafeBroadcastToggle() }) {
                HStack(spacing: 10) {
                    Image(systemName: viewModel.isBroadcasting ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.title)
                            .font(.system(size: 16, weight: .bold))
                        Text(model.subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .opacity(0.85)
                    }
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                        .fill(viewModel.isBroadcasting
                              ? StudioTheme.statusLive
                              : (model.hasExternalDisplay ? StudioTheme.actionPrimary : StudioTheme.statusMuted))
                )
            }
            .buttonStyle(.plain)
            .focusable(false)
            .disabled(!model.isEnabled)
            .help(model.helpText)
            .accessibilityLabel(model.title)
            .accessibilityHint(model.subtitle)

            if let title = model.warningTitle,
               let message = model.warningMessage {
                InlineWarningBanner(title: title, message: message, kind: .warn)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .fill(StudioTheme.surfaceSecondary)
        )
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

    // Issue #5: 精确扫描 Keynote 窗口（System Events AppleScript）
    private func scanKeynoteWindows() {
        viewModel.scanAndAddKeynoteWindows()

        // 如果没扫描到，给提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if viewModel.programItems.isEmpty {
                let alert = NSAlert()
                alert.messageText = "未发现 Keynote 文件"
                alert.informativeText = "请先在 Keynote 中打开 .key 文件，再点击扫描。\n\n提示：Keynote 需要已打开文件并出现在前台。"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "好的")
                alert.runModal()
            }
        }
    }

    // Issue #5: 导入 Keynote 文件（支持 .key 和 .keynote 后缀）
    private func importKeynotePicker() {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.title = "选择 Keynote 文件"
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false

            // Issue #5: 支持 key 和 keynote 后缀
            var allowedTypes: [UTType] = []
            if let keynoteType = UTType("com.apple.iWork.Keynote.key") {
                allowedTypes.append(keynoteType)
            }
            if let keynoteType2 = UTType("com.apple.keynote.key") {
                allowedTypes.append(keynoteType2)
            }
            if allowedTypes.isEmpty {
                allowedTypes = [.data]
            }
            panel.allowedContentTypes = allowedTypes

            // 同时通过后缀放行
            panel.allowedContentTypes = allowedTypes

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

// MARK: - 单行信号源（Issue #4: 放大字体；Issue #5: 拖拽进度 Slider）

struct SignalSourceRow: View {
    let item: ProgramItem
    let queuePosition: Int
    let queueRole: QueueRole
    let isSelected: Bool
    let isBroadcasting: Bool
    let isPlaying: Bool
    let avCoordinator: AVPlayerCoordinator
    let onSelect: () -> Void
    let onTogglePause: () -> Void
    let onEndHTML: () -> Void
    let onJumpToBeginning: () -> Void
    var onSkipToEnd: (() -> Void)? = nil
    let onDelete: () -> Void

    @State private var isHovered = false

    private var rowModel: ProgramQueueRowModel {
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
                queueBadge

                Image(systemName: iconName(for: item))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(sourceTint)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                            .fill(sourceTint.opacity(queueRole == .current ? 0.18 : 0.11))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 14, weight: queueRole == .current ? .bold : .semibold))
                        .foregroundStyle(StudioTheme.textPrimary)
                        .lineLimit(1)
                        .help(item.title)

                    Text(statusText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(statusTint)
                        .lineLimit(1)
                }
                .opacity(contentOpacity)
                .layoutPriority(1)

                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                stateBadge
                sourceTypeChip
                Spacer(minLength: 0)
            }
            .padding(.leading, 50)
            .fixedSize(horizontal: false, vertical: true)

            if isSelected && rowModel.controlStyle != .none && rowModel.controlStyle != .unsupported {
                selectedControlRail
            }

            // 进度 Slider（仅媒体源选中时显示）
            if isSelected && rowModel.showsProgressSlider {
                ProgressSliderRow(avCoordinator: avCoordinator)
                    .padding(.leading, 50)
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .background(backgroundFill)
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                .stroke(borderColor, lineWidth: queueRole == .current ? 1.4 : 0.9)
        )
        .clipShape(RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous))
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var selectedControlRail: some View {
        HStack(spacing: 10) {
            Text(rowModel.controlRailLabel)
                .font(.system(size: 10, weight: .black, design: .rounded))
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
                        accessibilityLabel: "Jump current program to beginning",
                        tint: currentRowControlTint,
                        fill: currentRowControlTint.opacity(0.12),
                        action: onJumpToBeginning
                    )
                    .help("跳回开头")

                    if let onSkipToEnd {
                        controlButton(
                            systemName: "forward.end.fill",
                            accessibilityLabel: "Skip current program to end",
                            tint: currentRowControlTint,
                            fill: currentRowControlTint.opacity(0.12),
                            action: onSkipToEnd
                        )
                        .help("Skip to end（跳至结束）")
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
                accessibilityLabel: "Delete \(item.title)",
                tint: StudioTheme.actionDanger,
                fill: StudioTheme.actionDanger.opacity(isHovered ? 0.12 : 0.04),
                action: onDelete
            )
            .opacity(isHovered ? 1 : 0.28)
            .help("删除")
        }
        .padding(.leading, 50)
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
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
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
                background: isBroadcasting ? StudioTheme.statusLive : StudioTheme.actionPrimary
            )
        case .next:
            badge(
                text: rowModel.stateBadgeText ?? "NEXT",
                foreground: StudioTheme.statusWarn,
                background: StudioTheme.statusWarn.opacity(0.14)
            )
        case .queued:
            EmptyView()
        }
    }

    private var sourceTypeChip: some View {
        Text(sourceLabel)
            .font(.system(size: 10, weight: .bold, design: .rounded))
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

    private var queueBadge: some View {
        Text(queueBadgeText)
            .font(.system(size: queueRole == .current ? 11 : 10, weight: .black, design: .rounded))
            .foregroundStyle(queueBadgeForeground)
            .frame(minWidth: 28)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: StudioTheme.radiusS, style: .continuous)
                    .fill(queueBadgeBackground)
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
            return (isBroadcasting ? StudioTheme.statusLive : StudioTheme.actionPrimary).opacity(0.08)
        case .next:
            return StudioTheme.statusWarn.opacity(isHovered ? 0.11 : 0.07)
        case .queued:
            return isHovered ? StudioTheme.surfaceSecondary.opacity(0.8) : Color.clear
        }
    }

    private var borderColor: Color {
        switch queueRole {
        case .current:
            return isBroadcasting ? StudioTheme.borderCritical : StudioTheme.borderActive
        case .next:
            return StudioTheme.statusWarn.opacity(0.24)
        case .queued:
            return isHovered ? StudioTheme.borderSubtle : Color.clear
        }
    }

    private var sourceLabel: String {
        item.displaySourceLabel
    }

    private var currentRowControlTint: Color {
        isBroadcasting ? StudioTheme.statusLive : StudioTheme.actionPrimary
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
            return StudioTheme.statusWarn
        case .queued:
            return .secondary
        }
    }

    private var queueBadgeText: String {
        rowModel.queueBadgeText
    }

    private var queueBadgeForeground: Color {
        switch queueRole {
        case .current:
            return .white
        case .next:
            return StudioTheme.statusWarn
        case .queued:
            return StudioTheme.textSecondary
        }
    }

    private var queueBadgeBackground: Color {
        switch queueRole {
        case .current:
            return isBroadcasting ? StudioTheme.statusLive : StudioTheme.actionPrimary
        case .next:
            return StudioTheme.statusWarn.opacity(0.14)
        case .queued:
            return StudioTheme.surfaceSecondary
        }
    }

    private var sourceTint: Color {
        switch item.sourceKind {
        case .keynote, .activeDeck:
            return StudioTheme.statusMuted
        case .pptx:
            return StudioTheme.statusWarn
        case .html:
            return StudioTheme.statusReady
        case .media:
            return item.isVideoMedia ? StudioTheme.actionPrimary : StudioTheme.pink
        case .unsupported:
            return StudioTheme.textSecondary
        }
    }

    private func badge(text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .rounded))
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
        case .unsupported:
            return "doc.fill"
        }
    }
}

// MARK: - 可拖拽进度 Slider（双向绑定 AVPlayerCoordinator）

struct ProgressSliderRow: View {
    @ObservedObject var avCoordinator: AVPlayerCoordinator
    @State private var isDragging = false
    @State private var dragValue: Double = 0.0

    private var displayProgress: Double {
        isDragging ? dragValue : avCoordinator.progress
    }

    var body: some View {
        HStack(spacing: 6) {
            // 当前时间
            Text(formatTime(avCoordinator.currentTime))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(StudioTheme.textSecondary)
                .frame(width: 38, alignment: .leading)

            // 拖拽进度条
            Slider(
                value: Binding(
                    get: { displayProgress },
                    set: { newValue in
                        isDragging = true
                        dragValue = newValue
                    }
                ),
                in: 0...1
            ) { editing in
                if !editing && isDragging {
                    if let dur = avCoordinator.duration {
                        avCoordinator.seek(to: dragValue * dur)
                    }
                    isDragging = false
                }
            }
            .tint(StudioTheme.actionPrimary)
            .accessibilityLabel("Current program progress")
            .accessibilityValue("\(formatTime(avCoordinator.currentTime)) of \(avCoordinator.duration.map { formatTime($0) } ?? "unknown duration")")

            // 总时长
            Text(avCoordinator.duration.map { formatTime($0) } ?? "--:--")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(StudioTheme.textSecondary)
                .frame(width: 38, alignment: .trailing)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
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
