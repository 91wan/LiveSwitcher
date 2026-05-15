import SwiftUI
import UniformTypeIdentifiers

// MARK: - Main view

struct ContentView: View {
    @EnvironmentObject var viewModel: SwitcherViewModel

    var body: some View {
        VStack(spacing: 0) {
            primaryNavigationBar
            LiveStatusStrip(model: liveStatusModel)

            mainContent

            // ─── 底部状态栏 ───
            StatusBar()
        }
        .background(StudioTheme.canvasGradient)
        .frame(minWidth: AppConfiguration.minWindowWidth,
               minHeight: AppConfiguration.minWindowHeight)
        .preferredColorScheme(.light)
        // V21 Fix #3: 使用 GlobalKeyMonitor 替代 onKeyPress，解决字符键失效问题
        .background(GlobalKeyMonitor(viewModel: viewModel))
    }

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            StudioTheme.canvasGradient
                .ignoresSafeArea()

            switch viewModel.selectedMainTab {
            case .preview:
                previewConsole
            case .audioMixer:
                AudioMixerView()
                    .frame(maxWidth: 940, maxHeight: .infinity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .overlays:
                SettingsView()
                    .frame(maxWidth: 1100, maxHeight: .infinity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var previewConsole: some View {
        HStack(alignment: .top, spacing: 12) {
            LeftPanel()
                .frame(width: StudioTheme.directorRailWidth)
                .layoutPriority(1)

            ProgramMonitorView()
                .frame(minWidth: 500, idealWidth: 720, maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(3)

            LiveControlColumn {
                viewModel.selectedMainTab = .audioMixer
            }
            .frame(width: StudioTheme.directorRailWidth)
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 0)
    }

    private var primaryNavigationBar: some View {
        HStack(spacing: 16) {
            Spacer(minLength: 0)
            navigationTabCluster
                .layoutPriority(1)
            Spacer(minLength: 16)
            MainToolbar(
                embedded: true,
                onOpenPreview: { viewModel.selectedMainTab = .preview },
                onOpenAudioMixer: { viewModel.selectedMainTab = .audioMixer },
                onOpenOverlays: { viewModel.selectedMainTab = .overlays }
            )
                .layoutPriority(2)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(minHeight: 76)
        .background(Color.white.opacity(0.55))
        .overlay(Divider(), alignment: .bottom)
    }

    private var navigationTabCluster: some View {
        HStack(spacing: 6) {
            navigationTab(title: "预览 / 切换", systemName: "play.square.stack.fill", tag: .preview)
            navigationTab(title: "音频混音", systemName: "slider.horizontal.3", tag: .audioMixer)
            navigationTab(title: "叠层 / 字幕", systemName: "rectangle.3.group.bubble.left.fill", tag: .overlays)
        }
        .padding(5)
        .background(Capsule(style: .continuous).fill(StudioTheme.surfacePrimary))
        .overlay(Capsule(style: .continuous).stroke(StudioTheme.borderSubtle, lineWidth: 1))
    }

    private func navigationTab(title: String, systemName: String, tag: MainConsoleTab) -> some View {
        NavigationTabButton(title: title, systemImage: systemName, isSelected: viewModel.selectedMainTab == tag) {
            withAnimation(.easeInOut(duration: 0.16)) {
                viewModel.selectedMainTab = tag
            }
        }
    }

    private var liveStatusModel: LiveStatusBarModel {
        LiveStatusBarModel.make(
            snapshot: viewModel.livePreflightSnapshot,
            nextProgramTitle: nextProgramTitle
        )
    }

    private var nextProgramTitle: String? {
        guard !viewModel.programItems.isEmpty else { return nil }
        guard let currentID = viewModel.currentProgramItem?.id,
              let currentIndex = viewModel.programItems.firstIndex(where: { $0.id == currentID })
        else {
            return viewModel.programItems.first?.title
        }
        let nextIndex = viewModel.programItems.index(after: currentIndex)
        guard nextIndex < viewModel.programItems.endIndex else { return nil }
        return viewModel.programItems[nextIndex].title
    }
}

private struct LiveStatusStrip: View {
    let model: LiveStatusBarModel

    var body: some View {
        HStack(spacing: StudioTheme.spacingS) {
            statusItem(model.projection, prominent: true)
            statusItem(model.current)
            statusItem(model.next)
            statusItem(model.audio)
            Spacer(minLength: StudioTheme.spacingS)
            StatusBadge(model.panic.value == "Active" ? "Panic Active" : "Panic Off", kind: model.panic.status)
            StatusBadge("Speaker \(model.speaker.value)", kind: model.speaker.status)
            StatusBadge("PPT \(model.ppt.value)", kind: model.ppt.status)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(model.isCritical ? StudioTheme.statusLive.opacity(0.08) : StudioTheme.surfaceSecondary.opacity(0.92))
        .overlay(
            Rectangle()
                .fill(model.isCritical ? StudioTheme.borderCritical : StudioTheme.borderSubtle)
                .frame(height: 1),
            alignment: .bottom
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Live status. \(model.projection.title) \(model.projection.value). \(model.current.title) \(model.current.value). \(model.next.title) \(model.next.value). \(model.audio.value). Panic \(model.panic.value). Speaker \(model.speaker.value). PPT \(model.ppt.value).")
    }

    private func statusItem(_ item: LiveStatusBarModel.Item, prominent: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(item.title.uppercased())
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(StudioTheme.textTertiary)
            Text(item.value)
                .font(.system(size: prominent ? 12 : 11, weight: prominent ? .black : .bold))
                .foregroundStyle(StudioTheme.statusColor(item.status))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(StudioTheme.statusColor(item.status).opacity(0.08), in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(StudioTheme.statusColor(item.status).opacity(prominent ? 0.26 : 0.14), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title): \(item.value)")
    }
}

// MARK: - 右侧：现场控制区

struct LiveControlColumn: View {
    @EnvironmentObject private var viewModel: SwitcherViewModel
    let onOpenMixer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("现场控制区")
                        .font(StudioTheme.title())
                        .foregroundStyle(StudioTheme.textPrimary)
                    Text("音量 / BGM / 主讲人")
                        .font(StudioTheme.caption())
                        .foregroundStyle(StudioTheme.textSecondary)
                }
                Spacer()
                StatusBadge(viewModel.isBroadcasting ? "ON AIR" : "READY", kind: viewModel.isBroadcasting ? .live : .ready)
            }
            .padding(.horizontal, 4)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    BGMPlaylistPanel(mode: .liveDock)
                    RightPanel(mode: .liveQuick, onOpenMixer: onOpenMixer)
                }
                .padding(.bottom, 4)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - V21 Fix #3: 全局键盘监听器（NSEvent.addLocalMonitorForEvents 可靠拦截字符键）

struct GlobalKeyMonitor: NSViewRepresentable {
    @ObservedObject var viewModel: SwitcherViewModel

    func makeNSView(context: Context) -> NSView {
        let view = KeyMonitorView()
        view.viewModel = viewModel
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? KeyMonitorView)?.viewModel = viewModel
    }
}

final class KeyMonitorView: NSView {
    var viewModel: SwitcherViewModel?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            installMonitor()
        } else {
            removeMonitor()
        }
    }

    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let vm = self.viewModel else { return event }
            return self.handleKey(event: event, vm: vm)
        }
    }

    private func removeMonitor() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }

    deinit {
        removeMonitor()
    }

    private func handleKey(event: NSEvent, vm: SwitcherViewModel) -> NSEvent? {
        // MARK: - Tier1: ⌘⌥B → 老板键（在 modifiers guard 之前处理）
        // B = keyCode 11（QWERTY 键盘上 B 键）
        if event.modifierFlags.contains([.command, .option]) &&
           !event.modifierFlags.contains(.control) &&
           event.keyCode == 11 {
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.25)) {
                    vm.togglePanicMode()
                }
            }
            return nil   // 消费此事件，不继续传递
        }

        // 跳过有修饰键的组合（避免和系统/菜单冲突）
        let modifiers = event.modifierFlags.intersection([.command, .option, .control])
        guard modifiers.isEmpty else { return event }

        // 如果当前焦点在文本框，不拦截
        if let fr = window?.firstResponder, fr is NSText { return event }

        switch event.keyCode {
        // [ = keyCode 33
        case 33:
            Task { @MainActor in vm.bgmVolumeDown() }
            return nil
        // ] = keyCode 30
        case 30:
            Task { @MainActor in vm.bgmVolumeUp() }
            return nil
        // , = keyCode 43
        case 43:
            Task { @MainActor in
                if let bgm = vm.currentBGMItem {
                    vm.toggleBGM(bgm)
                } else if let first = vm.bgmItems.first {
                    vm.toggleBGM(first)
                }
            }
            return nil
        // Space = keyCode 49
        case 49:
            Task { @MainActor in
                if let item = vm.currentProgramItem {
                    vm.togglePause(for: item)
                }
            }
            return nil
        // Left Arrow = keyCode 123
        case 123:
            Task { @MainActor in vm.keynotePreviousSlide() }
            return nil
        // Right Arrow = keyCode 124
        case 124:
            Task { @MainActor in vm.keynoteNextSlide() }
            return nil
        default:
            // 数字键 1-9 (keyCodes: 18-26 for 1-9 on main keyboard)
            let numKeyCodes: [UInt16: Int] = [18:1, 19:2, 20:3, 21:4, 23:5, 22:6, 26:7, 28:8, 25:9]
            if let idx = numKeyCodes[event.keyCode] {
                Task { @MainActor in vm.switchToProgram(at: idx - 1) }
                return nil
            }
            return event
        }
    }
}

// MARK: - 底部状态栏

struct StatusBar: View {
    @EnvironmentObject var viewModel: SwitcherViewModel

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.programItems.isEmpty ? StudioTheme.statusIdle : StudioTheme.statusReady)
                .frame(width: 7, height: 7)
            Text(viewModel.programItems.isEmpty ? "就绪 - 请添加信号源" : "就绪 - \(viewModel.programItems.count) 个待播放项目")
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 24)
        .background(StudioTheme.surfacePrimary.opacity(0.68))
        .overlay(Divider(), alignment: .top)
    }
}

// MARK: - 中栏：Program Monitor + 壁纸库

struct ProgramMonitorView: View {
    @EnvironmentObject var viewModel: SwitcherViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Program Monitor")
                    .font(StudioTheme.title())
                    .foregroundStyle(StudioTheme.textPrimary)
                Text("Current / Next are the operator focus")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textTertiary)
                Spacer()
                StatusBadge(viewModel.isBroadcasting ? "ON AIR" : "PREVIEW", kind: viewModel.isBroadcasting ? .live : .idle)
            }

            previewDeck

            currentNextInfoRow

            if !viewModel.programItems.isEmpty {
                programPresetRow
            }

            transitionControlCard

            wallpaperTrayCard

            Spacer(minLength: 0)
        }
        .padding(20)
        .studioCard(cornerRadius: 30)
    }

    private var previewDeck: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: StudioTheme.monitorRadius, style: .continuous)
                .fill(StudioTheme.monitorGradient)

            RoundedRectangle(cornerRadius: StudioTheme.monitorRadius, style: .continuous)
                .stroke(StudioTheme.monitorBorder, lineWidth: 1)

            mediaLayer
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .clipShape(.rect(cornerRadius: StudioTheme.monitorRadius, style: .continuous))
                .animation(.easeInOut(duration: viewModel.crossfadeDuration),
                           value: viewModel.currentProgramItem)

            if viewModel.isBroadcasting {
                RoundedRectangle(cornerRadius: StudioTheme.monitorRadius, style: .continuous)
                    .stroke(StudioTheme.borderCritical.opacity(0.95), lineWidth: 3)
                    .padding(1)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isBroadcasting ? StudioTheme.statusLive : StudioTheme.statusIdle)
                    .frame(width: 8, height: 8)
                Text(viewModel.isBroadcasting ? "ON AIR" : "STANDBY")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(StudioTheme.monitorText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Text(monitorDisplayMode)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(StudioTheme.monitorText.opacity(0.82))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(StudioTheme.monitorOverlayFill, in: Capsule())
                .padding(.top, 14)
                .padding(.trailing, 14)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: 360)
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .shadow(color: StudioTheme.shadowStrong, radius: 12, x: 0, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.isBroadcasting ? "Program monitor on air" : "Program monitor standby")
    }

    private var currentNextInfoRow: some View {
        HStack(spacing: 10) {
            monitorInfoBlock(
                title: "Current",
                value: viewModel.currentProgramItem?.title ?? "No Program",
                subtitle: currentProgramSubtitle,
                status: viewModel.isBroadcasting ? .live : (viewModel.currentProgramItem == nil ? .warn : .idle)
            )
            monitorInfoBlock(
                title: "Next",
                value: nextProgramItem?.title ?? "None",
                subtitle: nextProgramItem?.subtitle.uppercased() ?? "Queue empty",
                status: nextProgramItem == nil ? .idle : .ready
            )
        }
    }

    private func monitorInfoBlock(title: String, value: String, subtitle: String, status: StudioTheme.StatusKind) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.uppercased())
                    .font(StudioTheme.statusLabel())
                    .foregroundStyle(StudioTheme.textTertiary)
                Spacer()
                StatusBadge(status == .live ? "ON AIR" : (status == .ready ? "NEXT" : status.accessibilityName.uppercased()), kind: status)
            }
            Text(value)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(StudioTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(subtitle)
                .font(StudioTheme.caption())
                .foregroundStyle(StudioTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StudioTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(status == .live ? StudioTheme.borderCritical : StudioTheme.borderSubtle, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value), \(subtitle)")
    }

    private var programPresetRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("节目总线")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textTertiary)
                ForEach(Array(viewModel.programItems.enumerated()), id: \.element.id) { index, item in
                    monitorSourceButton(item: item, index: index)
                }
            }
            .padding(.vertical, 2)
        }
        .opacity(0.82)
    }

    private var transitionControlCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("转场控制")
                    .font(StudioTheme.sectionTitle())
                    .foregroundStyle(StudioTheme.textPrimary)
                Text("Utility")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textTertiary)
            }

            Slider(
                value: $viewModel.crossfadeDuration,
                in: 0.5...3.0,
                step: 0.05
            )
            .tint(StudioTheme.statusWarn)
            .accessibilityLabel("Transition duration")
            .accessibilityValue(String(format: "%.1f seconds", viewModel.crossfadeDuration))

            Text(String(format: "%.1fs", viewModel.crossfadeDuration))
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(StudioTheme.statusWarn)
                .frame(width: 56, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    private var wallpaperTrayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Standby Wallpaper")
                        .font(StudioTheme.sectionTitle())
                        .foregroundStyle(StudioTheme.textPrimary)
                }
                Spacer()
                CountPill("\(viewModel.backgroundWallpapers.count) 张", kind: viewModel.backgroundWallpapers.isEmpty ? .warn : .ready)
            }

            if viewModel.backgroundWallpapers.isEmpty {
                EmptyStateView(title: "No standby wallpaper", message: "Import a neutral image for safe fallback.", systemImage: "photo")
            } else {
                WallpaperGalleryRow()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .fill(StudioTheme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: StudioTheme.radiusL, style: .continuous)
                .stroke(StudioTheme.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - 媒体层

    @ViewBuilder
    private var mediaLayer: some View {
        if viewModel.avCoordinator.isPlaying {
            VideoPlayerView(coordinator: viewModel.avCoordinator)
                .transition(.opacity)
        } else if let item = viewModel.currentProgramItem {
            VStack(spacing: 8) {
                Text(item.title)
                    .font(.system(size: 28, weight: .bold))
                .foregroundStyle(StudioTheme.monitorText)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(StudioTheme.monitorText.opacity(0.6))
                }
            }
            .transition(.opacity)
        } else {
            VStack(spacing: 8) {
                Text("待机中")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(StudioTheme.monitorText)
                Text("NO SIGNAL LOADED")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(StudioTheme.monitorText.opacity(0.7))
            }
            .transition(.opacity)
        }
    }

    private var monitorDisplayMode: String {
        if viewModel.currentHTMLURL != nil {
            return "HTML"
        }
        if viewModel.avCoordinator.isPlaying {
            return "VIDEO"
        }
        if viewModel.currentProgramItem != nil {
            return "READY"
        }
        return viewModel.backgroundImage != nil ? "WALLPAPER READY" : "IDLE"
    }

    private var currentProgramSubtitle: String {
        if viewModel.currentHTMLURL != nil { return "HTML is loaded" }
        if viewModel.avCoordinator.isPlaying { return "Media playing" }
        return viewModel.currentProgramItem?.subtitle.uppercased() ?? "Standby"
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

    private func monitorSourceButton(item: ProgramItem, index: Int) -> some View {
        let isActive = viewModel.currentProgramItem?.id == item.id

        return Button {
            viewModel.switchToProgram(at: index)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(index + 1)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(isActive ? StudioTheme.monitorText : StudioTheme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(isActive ? StudioTheme.actionPrimary : StudioTheme.surfaceSecondary)
                    )

                Text(item.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(StudioTheme.textPrimary)
                    .lineLimit(1)
            }
            .frame(width: 112, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                    .fill(isActive ? StudioTheme.actionPrimary.opacity(0.10) : StudioTheme.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: StudioTheme.radiusM, style: .continuous)
                    .stroke(isActive ? StudioTheme.actionPrimary.opacity(0.35) : StudioTheme.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

}

// MARK: - 壁纸库横向滚动行

enum WallpaperDropSupport {
    static func decodeFileURL(from item: Any?) -> URL? {
        if let url = item as? URL {
            return url.isFileURL ? url : nil
        }

        if let data = item as? Data,
           let url = URL(dataRepresentation: data, relativeTo: nil) {
            return url.isFileURL ? url : nil
        }

        if let string = item as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmed), url.isFileURL {
                return url
            }
            guard trimmed.hasPrefix("/") || trimmed.hasPrefix("~") else { return nil }
            let expandedPath = NSString(string: trimmed).expandingTildeInPath
            return URL(fileURLWithPath: expandedPath)
        }

        return nil
    }
}

struct WallpaperGalleryRow: View {
    @EnvironmentObject var viewModel: SwitcherViewModel
    @State private var isDroppingWallpaper = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 14))
                    .foregroundStyle(StudioTheme.textSecondary)
                Text("待机图库")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(StudioTheme.textPrimary)
                Spacer()
                Button("导入...") {
                    openWallpaperPicker()
                }
                .font(.system(size: 13))
                .buttonStyle(.plain)
                .foregroundStyle(StudioTheme.actionPrimary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.backgroundWallpapers, id: \.self) { url in
                        WallpaperThumbView(url: url, isActive: viewModel.activeWallpaperURL == url)
                            .onTapGesture {
                                viewModel.setActiveWallpaper(url: url)
                            }
                            .contextMenu {
                                Button("删除") {
                                    viewModel.removeWallpaper(url: url)
                                }
                            }
                    }

                    // 拖拽放入占位
                    ZStack {
                        RoundedRectangle(cornerRadius: StudioTheme.radiusS)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                            .foregroundStyle(isDroppingWallpaper ? StudioTheme.actionPrimary : StudioTheme.borderSubtle)
                            .background(
                                RoundedRectangle(cornerRadius: StudioTheme.radiusS)
                                    .fill(isDroppingWallpaper ? StudioTheme.actionPrimary.opacity(0.05) : StudioTheme.surfaceSecondary)
                            )

                        VStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .light))
                                .foregroundStyle(StudioTheme.textSecondary)
                            Text("拖入图片")
                                .font(.system(size: 10))
                                .foregroundStyle(StudioTheme.textSecondary)
                        }
                    }
                    .frame(width: 80, height: 60)
                    .onDrop(of: [.fileURL, .image], isTargeted: $isDroppingWallpaper) { providers in
                        handleWallpaperDrop(providers: providers)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func openWallpaperPicker() {
        let panel = NSOpenPanel()
        panel.title = "选择壁纸图片"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image, .png, .jpeg, .gif]
        guard panel.runModal() == .OK else { return }
        var firstAcceptedURL: URL?
        for url in panel.urls {
            if viewModel.addWallpaper(url: url), firstAcceptedURL == nil {
                firstAcceptedURL = url
            }
        }
        if let firstAcceptedURL {
            viewModel.setActiveWallpaper(url: firstAcceptedURL)
        }
    }

    private func handleWallpaperDrop(providers: [NSItemProvider]) -> Bool {
        var didRequestImport = false

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                didRequestImport = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let url = WallpaperDropSupport.decodeFileURL(from: item) else { return }
                    importWallpaperOnMain(url)
                }
                continue
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                didRequestImport = true
                provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
                    guard let url,
                          let persistedURL = persistDroppedWallpaperFile(from: url) else { return }
                    importWallpaperOnMain(persistedURL)
                }
            }
        }

        return didRequestImport
    }

    private func persistDroppedWallpaperFile(from sourceURL: URL) -> URL? {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let directoryURL = appSupportURL
            .appendingPathComponent("LiveSwitcher", isDirectory: true)
            .appendingPathComponent("Wallpapers", isDirectory: true)

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let fallbackExtension = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
            let destinationURL = directoryURL
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fallbackExtension)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            return nil
        }
    }

    private func importWallpaperOnMain(_ url: URL) {
        DispatchQueue.main.async {
            if viewModel.addWallpaper(url: url) {
                viewModel.setActiveWallpaper(url: url)
            }
        }
    }
}

// MARK: - 壁纸缩略图

struct WallpaperThumbView: View {
    let url: URL
    let isActive: Bool

    var body: some View {
        ZStack {
            if let img = NSImage(contentsOf: url) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: StudioTheme.radiusS))
            } else {
                RoundedRectangle(cornerRadius: StudioTheme.radiusS)
                    .fill(StudioTheme.surfaceSecondary)
                    .frame(width: 80, height: 60)
                Image(systemName: "photo")
                    .foregroundStyle(StudioTheme.textSecondary)
            }

            if isActive {
                RoundedRectangle(cornerRadius: StudioTheme.radiusS)
                    .stroke(StudioTheme.actionPrimary, lineWidth: 3)
                    .frame(width: 80, height: 60)

                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(StudioTheme.actionPrimary)
                            .background(StudioTheme.surfacePrimary.clipShape(Circle()))
                            .padding(4)
                    }
                    Spacer()
                }
                .frame(width: 80, height: 60)
            }
        }
        .frame(width: 80, height: 60)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(SwitcherViewModel())
}
