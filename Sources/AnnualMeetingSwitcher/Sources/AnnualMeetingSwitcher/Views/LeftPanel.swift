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

            // ── 已添加信号源列表（如果有）──
            if !viewModel.programItems.isEmpty {
                sourceList
            }

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
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.85, green: 0.2, blue: 0.2))
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
                    .foregroundStyle(.blue)
                Text("播毕自动下一条视频")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.66))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.82), lineWidth: 1)
        )
        .help("仅当前节目播毕且下一条也是视频时自动播放；不会自动打开 HTML、PPT 或 Keynote。")
    }

    // MARK: - 标题行

    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("播放队列")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("\(viewModel.programItems.count) 个节目")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("\(viewModel.programItems.count)")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(.blue)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.1))
                )
            Button(action: { viewModel.scanAndAddKeynoteWindows() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor))
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
                Text("导入素材")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
                Text("VIDEO / PPT / HTML")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            HStack(spacing: 8) {
                Button("选择视频") {
                    openFilePicker(types: [.movie, .audio])
                }
                .buttonStyle(ImportActionCardStyle(color: .blue, systemName: "film.fill"))

                Button("选择 PPTX") {
                    openPPTXPicker()
                }
                .buttonStyle(ImportActionCardStyle(color: .orange, systemName: "doc.richtext.fill"))
            }

            Button("选择 HTML（大屏展示）") {
                openHTMLPicker()
            }
            .buttonStyle(ImportWideButtonStyle(color: .green, systemName: "globe.asia.australia.fill"))
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.84), lineWidth: 1)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
            handleDrop(providers: providers)
        }
    }

    // MARK: - 已添加信号源列表（Issue #10: 显示拖拽排序手柄）

    private var sourceList: some View {
        let currentIndex = viewModel.programItems.firstIndex { $0.id == viewModel.currentProgramItem?.id }

        return List {
            ForEach(Array(viewModel.programItems.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 6) {
                    // Issue #10: 显式排序手柄图标
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.secondary.opacity(0.6))
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
                        onJumpToBeginning: { viewModel.seekProgramItemToStart(item) },
                        onSkipToEnd: ["mp4","mov","m4v","avi"].contains(item.subtitle.lowercased()) ? { viewModel.seekProgramItemToEnd(item) } : nil,
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
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.84), lineWidth: 1)
        )
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("输出屏幕")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        Image(systemName: SecondScreenSelector.pickExternal() != nil ? "display.2" : "display")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(SecondScreenSelector.pickExternal() != nil ? "外接屏幕" : "未接副屏")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
                Spacer()
                Text(viewModel.isBroadcasting ? "ON AIR" : "待机")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(viewModel.isBroadcasting ? .white : .blue)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(viewModel.isBroadcasting ? Color.red : Color.blue.opacity(0.12))
                    )
            }

            Button(action: { viewModel.handleSafeBroadcastToggle() }) {
                HStack(spacing: 10) {
                    Image(systemName: viewModel.isBroadcasting ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.isBroadcasting ? "投射：开" : "投射：关")
                            .font(.system(size: 16, weight: .bold))
                        Text(viewModel.isBroadcasting ? "副屏输出中 · 点击停止" : "点击推流至副屏")
                            .font(.system(size: 12, weight: .medium))
                            .opacity(0.85)
                    }
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(viewModel.isBroadcasting
                              ? Color(red: 0.05, green: 0.65, blue: 0.35)  // 开启：深绿
                              : Color(red: 0.18, green: 0.42, blue: 0.88)) // 关闭：蓝色
                )
                .shadow(color: viewModel.isBroadcasting
                        ? Color.green.opacity(0.4)
                        : Color.blue.opacity(0.3),
                        radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .focusable(false)

            if let notice = viewModel.broadcastSafetyNotice {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(notice)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .lineLimit(2)
                }
                .foregroundStyle(Color.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.orange.opacity(0.10))
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
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
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    guard ProgramSourceKind(fileURL: url).isImportableFile else { return }
                    let programItem = ProgramItem(
                        title: url.deletingPathExtension().lastPathComponent,
                        subtitle: url.pathExtension.uppercased(),
                        sourceURL: url
                    )
                    viewModel.addProgramItem(programItem)
                }
            }
        }
        return true
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
                .opacity(0)
                .frame(width: 0, height: 0)
            }
        }
        .frame(width: 0, height: 0)
        .hidden()
    }
}

// MARK: - 大号胶囊按钮样式（Issue #4/10）

struct LargePillButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(isChromatic ? .white : Color.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(resolvedFillColor)
            )
            .opacity(configuration.isPressed ? 0.75 : 1.0)
    }

    /// 有彩色背景的按钮（用白色文字）
    private var isChromatic: Bool {
        color == .blue || color == .green || color == .red || color == .orange
    }

    /// 将 SwiftUI Color 映射为实际填充色，未匹配的退回系统控件色
    private var resolvedFillColor: Color {
        switch color {
        case .blue:   return .blue
        case .green:  return .green
        case .red:    return .red
        case .orange: return .orange
        default:      return Color(NSColor.controlColor)
        }
    }
}

// MARK: - 轻质感椭圆按钮样式（保留兼容）

struct LightPillButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(color == .blue ? .white : Color.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color == .blue ? Color.blue : Color(NSColor.controlColor))
            )
            .opacity(configuration.isPressed ? 0.75 : 1.0)
    }
}

struct ImportActionCardStyle: ButtonStyle {
    let color: Color
    let systemName: String

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
            configuration.label
                .font(.system(size: 14, weight: .bold))
                .lineLimit(1)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(configuration.isPressed ? 0.8 : 1))
        )
    }
}

struct ImportWideButtonStyle: ButtonStyle {
    let color: Color
    let systemName: String

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
            configuration.label
                .font(.system(size: 15, weight: .bold))
                .lineLimit(1)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(color.opacity(configuration.isPressed ? 0.8 : 1))
        )
    }
}

// MARK: - 单行信号源（Issue #4: 放大字体；Issue #5: 拖拽进度 Slider）

enum QueueRole {
    case current
    case next
    case queued
}

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
    let onJumpToBeginning: () -> Void
    var onSkipToEnd: (() -> Void)? = nil
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                queueBadge

                Image(systemName: iconName(for: item))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(sourceTint)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(sourceTint.opacity(queueRole == .current ? 0.18 : 0.11))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 14, weight: queueRole == .current ? .bold : .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(statusText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(statusTint)
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

            if isSelected {
                selectedControlRail
            }

            // 进度 Slider（仅在选中时显示）
            if isSelected {
                ProgressSliderRow(avCoordinator: avCoordinator)
                    .padding(.leading, 50)
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .background(backgroundFill)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(borderColor, lineWidth: queueRole == .current ? 1.4 : 0.9)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var selectedControlRail: some View {
        HStack(spacing: 10) {
            Text(isBroadcasting ? "LIVE 主控" : "PREVIEW 主控")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(currentRowControlTint)
                .lineLimit(1)

            HStack(spacing: 7) {
                controlButton(
                    systemName: isPlaying ? "pause.fill" : "play.fill",
                    tint: .white,
                    fill: currentRowControlTint,
                    action: onTogglePause
                )
                .help("暂停 / 播放")

                controlButton(
                    systemName: "backward.end.fill",
                    tint: currentRowControlTint,
                    fill: currentRowControlTint.opacity(0.12),
                    action: onJumpToBeginning
                )
                .help("跳回开头")

                if let onSkipToEnd {
                    controlButton(
                        systemName: "forward.end.fill",
                        tint: currentRowControlTint,
                        fill: currentRowControlTint.opacity(0.12),
                        action: onSkipToEnd
                    )
                    .help("Skip to end（跳至结束）")
                }
            }

            Spacer(minLength: 0)

            controlButton(
                systemName: "trash",
                tint: .red,
                fill: Color.red.opacity(0.12),
                action: onDelete
            )
            .help("删除")
        }
        .padding(.leading, 50)
        .padding(.top, 2)
    }

    private func controlButton(
        systemName: String,
        tint: Color,
        fill: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(fill)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var stateBadge: some View {
        switch queueRole {
        case .current:
            badge(
                text: isBroadcasting ? "ON AIR" : "PREVIEW",
                foreground: .white,
                background: isBroadcasting ? .red : .orange
            )
        case .next:
            badge(
                text: "NEXT",
                foreground: Color(red: 0.72, green: 0.43, blue: 0.02),
                background: Color(red: 0.99, green: 0.94, blue: 0.78)
            )
        case .queued:
            EmptyView()
        }
    }

    private var sourceTypeChip: some View {
        Text(sourceLabel)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(sourceTint)
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
            .foregroundColor(queueBadgeForeground)
            .frame(minWidth: 28)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(queueBadgeBackground)
            )
    }

    private var statusText: String {
        switch queueRole {
        case .current:
            if item.subtitle.lowercased() == "html" || item.subtitle.lowercased() == "htm" {
                return isBroadcasting ? "当前大屏展示" : "当前预监源"
            }
            if item.subtitle.lowercased().contains("key") || item.subtitle.lowercased().contains("ppt") {
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
            return isBroadcasting ? Color.red.opacity(0.08) : Color.blue.opacity(0.08)
        case .next:
            return Color.orange.opacity(isHovered ? 0.11 : 0.07)
        case .queued:
            return isHovered ? Color.gray.opacity(0.05) : Color.clear
        }
    }

    private var borderColor: Color {
        switch queueRole {
        case .current:
            return isBroadcasting ? Color.red.opacity(0.35) : Color.blue.opacity(0.28)
        case .next:
            return Color.orange.opacity(0.22)
        case .queued:
            return isHovered ? Color.gray.opacity(0.14) : Color.clear
        }
    }

    private var sourceLabel: String {
        switch item.subtitle.lowercased() {
        case "key", "keynote":
            return "KEY"
        case "key (活动)":
            return "DECK"
        case "pptx":
            return "PPTX"
        case "html", "htm":
            return "HTML"
        case "mp4", "mov", "m4v", "avi":
            return "VIDEO"
        case "mp3", "aac", "wav", "m4a":
            return "AUDIO"
        case "jpg", "jpeg", "png", "gif":
            return "IMAGE"
        default:
            return item.subtitle.uppercased()
        }
    }

    private var currentRowControlTint: Color {
        isBroadcasting ? .red : .blue
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
            return .orange
        case .queued:
            return .secondary
        }
    }

    private var queueBadgeText: String {
        switch queueRole {
        case .current:
            return "LIVE"
        case .next:
            return "\(queuePosition)"
        case .queued:
            return "\(queuePosition)"
        }
    }

    private var queueBadgeForeground: Color {
        switch queueRole {
        case .current:
            return .white
        case .next:
            return Color(red: 0.72, green: 0.43, blue: 0.02)
        case .queued:
            return .secondary
        }
    }

    private var queueBadgeBackground: Color {
        switch queueRole {
        case .current:
            return isBroadcasting ? .red : .blue
        case .next:
            return Color(red: 0.99, green: 0.94, blue: 0.78)
        case .queued:
            return Color.gray.opacity(0.1)
        }
    }

    private var sourceTint: Color {
        switch item.subtitle.lowercased() {
        case "key", "keynote", "key (活动)":
            return .purple
        case "pptx":
            return .orange
        case "html", "htm":
            return .green
        case "mp4", "mov", "m4v", "avi":
            return .blue
        case "mp3", "aac", "wav", "m4a":
            return .pink
        case "jpg", "jpeg", "png", "gif":
            return .teal
        default:
            return .secondary
        }
    }

    private func badge(text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundColor(foreground)
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
        switch item.subtitle.lowercased() {
            case "key", "keynote": return "play.rectangle.fill"
        case "pptx":           return "doc.richtext"
        case "html", "htm":    return "globe"
        case "mp4", "mov", "m4v", "avi": return "film"
        case "mp3", "aac", "wav", "m4a": return "music.note"
        case "jpg", "jpeg", "png", "gif": return "photo"
        default: return "doc.fill"
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
                .foregroundColor(.secondary)
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
            .tint(.blue)

            // 总时长
            Text(avCoordinator.duration.map { formatTime($0) } ?? "--:--")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
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
