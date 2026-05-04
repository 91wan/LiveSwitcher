import SwiftUI

// MARK: - Main view

struct ContentView: View {
    @EnvironmentObject var viewModel: SwitcherViewModel
    @FocusState private var isFocused: Bool
    @State private var selectedTab: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            primaryNavigationBar

            // ─── 内容区域（ZStack 常驻内存，避免切换时销毁重建卡顿）───
            ZStack {
                StudioTheme.canvasGradient
                    .ignoresSafeArea()

                // 主工作区（节目队列 | Program 监视器 | 现场控制）- 常驻内存
                HStack(alignment: .top, spacing: 12) {
                    LeftPanel()
                        .frame(width: StudioTheme.directorRailWidth)
                        .layoutPriority(1)

                    ProgramMonitorView()
                        .frame(minWidth: 500, idealWidth: 720, maxWidth: .infinity, maxHeight: .infinity)
                        .layoutPriority(3)

                    LiveControlColumn {
                        selectedTab = 1
                    }
                    .frame(width: StudioTheme.directorRailWidth)
                    .layoutPriority(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 10)
                .padding(.top, 4)
                .padding(.bottom, 0)
                .opacity(selectedTab == 0 ? 1 : 0)
                .allowsHitTesting(selectedTab == 0)

                // 音频混音页面（限宽居中，绝不撑爆窗口）
                AudioMixerView()
                    .frame(maxWidth: 800, maxHeight: .infinity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(selectedTab == 1 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 1)

                // 叠层 / 字幕页面（限宽居中，绝不撑爆窗口）
                SettingsView()
                    .frame(maxWidth: 800, maxHeight: .infinity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(selectedTab == 2 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 2)
            }

            // ─── 底部状态栏 ───
            StatusBar()
        }
        .background(StudioTheme.canvasGradient)
        .frame(minWidth: AppConfiguration.minWindowWidth,
               minHeight: AppConfiguration.minWindowHeight)
        .preferredColorScheme(.light)
        // V21 Fix #3: 使用 GlobalKeyMonitor 替代 onKeyPress，解决字符键失效问题
        .background(GlobalKeyMonitor(viewModel: viewModel))
        .focused($isFocused)
        .onAppear { isFocused = true }
    }

    private var primaryNavigationBar: some View {
        HStack(spacing: 16) {
            Spacer(minLength: 0)
            navigationTabCluster
                .layoutPriority(1)
            Spacer(minLength: 16)
            MainToolbar(embedded: true)
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
            navigationTab(title: "预览 / 切换", systemName: "play.square.stack.fill", tag: 0)
            navigationTab(title: "音频混音", systemName: "slider.horizontal.3", tag: 1)
            navigationTab(title: "叠层 / 字幕", systemName: "rectangle.3.group.bubble.left.fill", tag: 2)
        }
        .padding(5)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.85), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.07), radius: 16, x: 0, y: 8)
    }

    private func navigationTab(title: String, systemName: String, tag: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                selectedTab = tag
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(selectedTab == tag ? .white : .primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                Group {
                    if selectedTab == tag {
                        Capsule(style: .continuous)
                            .fill(StudioTheme.accentGradient)
                    } else {
                        Capsule(style: .continuous)
                            .fill(Color.clear)
                    }
                }
            )
            .shadow(color: selectedTab == tag ? StudioTheme.accent.opacity(0.28) : .clear, radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

// MARK: - 右侧：现场控制区

struct LiveControlColumn: View {
    let onOpenMixer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("现场控制区")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    Text("音量 / BGM / 主讲人")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("LIVE")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1), in: Capsule())
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
                .fill(viewModel.programItems.isEmpty ? Color.gray : Color.green)
                .frame(width: 7, height: 7)
            Text(viewModel.programItems.isEmpty ? "就绪 - 请添加信号源" : "就绪 - \(viewModel.programItems.count) 个待播放项目")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 24)
        .background(Color.white.opacity(0.6))
        .overlay(Divider(), alignment: .top)
    }
}

// MARK: - 中栏：Program Monitor + 壁纸库

struct ProgramMonitorView: View {
    @EnvironmentObject var viewModel: SwitcherViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Program 监视器")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)

            previewDeck

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
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.09, blue: 0.13),
                            Color(red: 0.03, green: 0.03, blue: 0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)

            mediaLayer
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .animation(.easeInOut(duration: viewModel.crossfadeDuration),
                           value: viewModel.currentProgramItem)

            if viewModel.isBroadcasting {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.red.opacity(0.95), lineWidth: 3)
                    .padding(1)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isBroadcasting ? Color.red : Color.green)
                    .frame(width: 8, height: 8)
                Text(viewModel.isBroadcasting ? "播出中" : "待机中")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.92))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Text(monitorDisplayMode)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.82))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08), in: Capsule())
                .padding(.top, 14)
                .padding(.trailing, 14)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: 360)
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 8)
    }

    private var programPresetRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(viewModel.programItems.enumerated()), id: \.element.id) { index, item in
                    monitorSourceButton(item: item, index: index)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var transitionControlCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("转场控制")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
            }

            Slider(
                value: $viewModel.crossfadeDuration,
                in: 0.5...3.0,
                step: 0.05
            )
            .tint(.purple)

            Text(String(format: "%.1fs", viewModel.crossfadeDuration))
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.purple)
                .frame(width: 56, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.82), lineWidth: 1)
        )
    }

    private var wallpaperTrayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("壁纸库")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                }
                Spacer()
                Text("\(viewModel.backgroundWallpapers.count) 张")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1), in: Capsule())
            }

            WallpaperGalleryRow()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.84), lineWidth: 1)
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
                    .foregroundColor(.white)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color(white: 0.6))
                }
            }
            .transition(.opacity)
        } else {
            VStack(spacing: 8) {
                Text("待机中")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                Text("NO SIGNAL LOADED")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.7))
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

    private func monitorSourceButton(item: ProgramItem, index: Int) -> some View {
        let isActive = viewModel.currentProgramItem?.id == item.id

        return Button {
            viewModel.switchToProgram(at: index)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(index + 1)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(isActive ? .white : .primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(isActive ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                    )

                Text(item.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(width: 112, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isActive ? Color.accentColor.opacity(0.10) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isActive ? Color.accentColor.opacity(0.35) : Color.black.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

}

// MARK: - 壁纸库横向滚动行

struct WallpaperGalleryRow: View {
    @EnvironmentObject var viewModel: SwitcherViewModel
    @State private var isDroppingWallpaper = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text("待机图库")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                Button("导入...") {
                    openWallpaperPicker()
                }
                .font(.system(size: 13))
                .buttonStyle(.plain)
                .foregroundColor(.blue)
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
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                            .foregroundColor(isDroppingWallpaper ? Color.blue : Color(NSColor.separatorColor))
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isDroppingWallpaper ? Color.blue.opacity(0.05) : Color(NSColor.controlBackgroundColor))
                            )

                        VStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .light))
                                .foregroundColor(.secondary)
                            Text("拖入图片")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
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
        for url in panel.urls {
            viewModel.addWallpaper(url: url)
        }
        if let first = panel.urls.first {
            viewModel.setActiveWallpaper(url: first)
        }
    }

    private func handleWallpaperDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    viewModel.addWallpaper(url: url)
                    viewModel.setActiveWallpaper(url: url)
                }
            }
        }
        return true
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
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(width: 80, height: 60)
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
            }

            if isActive {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue, lineWidth: 3)
                    .frame(width: 80, height: 60)

                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                            .background(Color.white.clipShape(Circle()))
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
