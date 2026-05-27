import SwiftUI

// MARK: - Main view

@MainActor
struct ContentView: View {
    @Environment(SwitcherViewModel.self) var viewModel
    @State private var loadedSetupTabs: Set<MainConsoleTab> = [.preview]

    var body: some View {
        VStack(spacing: 0) {
            primaryNavigationBar
            mainContent
        }
        .background(StudioTheme.canvasGradient)
        .frame(minWidth: AppConfiguration.minWindowWidth,
               minHeight: AppConfiguration.minWindowHeight)
        .preferredColorScheme(viewModel.themeOverride.colorScheme)
        // V21 Fix #3: 使用 GlobalKeyMonitor 替代 onKeyPress，解决字符键失效问题
        .background(GlobalKeyMonitor(viewModel: viewModel))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("LiveSwitcher main console")
        .onAppear {
            markSetupTabLoaded(viewModel.selectedMainTab)
        }
        .onChange(of: viewModel.selectedMainTab) { _, newTab in
            markSetupTabLoaded(newTab)
        }
        .onChange(of: viewModel.consoleMode) { _, newMode in
            if newMode == .setup {
                markSetupTabLoaded(viewModel.selectedMainTab)
            } else {
                trimLoadedSetupTabsForLiveMode()
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            ZStack {
                StudioTheme.canvasGradient
                    .ignoresSafeArea()

                if ConsoleModeMountPolicy.shouldMountSetupLayer(
                    consoleMode: viewModel.consoleMode,
                    selectedTab: viewModel.selectedMainTab,
                    loadedTabs: loadedSetupTabs
                ) {
                    consoleModeRetainedLayer(isActive: viewModel.consoleMode == .setup) {
                        setupContentTabs
                    }
                }

                if ConsoleModeMountPolicy.shouldMountLiveLayer(consoleMode: viewModel.consoleMode) {
                    consoleModeRetainedLayer(isActive: viewModel.consoleMode == .live) {
                        liveContent
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if SetupAudioDockModel.shouldShow(consoleMode: viewModel.consoleMode, selectedTab: viewModel.selectedMainTab) {
                SetupAudioDock {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        viewModel.navigateToSetup(.audioMixer)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var liveContent: some View {
        LiveModeView {
            viewModel.navigateToSetup(.audioMixer)
        }
    }

    private func consoleModeRetainedLayer<Content: View>(
        isActive: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Group {
            if isActive {
                content()
            } else {
                content()
                    .hidden()
            }
        }
        .allowsHitTesting(isActive)
        .accessibilityHidden(!isActive)
        .zIndex(isActive ? 1 : 0)
    }

    @ViewBuilder
    private var setupContentTabs: some View {
        if shouldMountSetupTab(.preview) {
            retainedTab(.preview) {
                runDesk()
            }
        }

        if shouldMountSetupTab(.audioMixer) {
            retainedTab(.audioMixer) {
                AudioMixerView()
                    .frame(maxWidth: 940, maxHeight: .infinity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }

        if shouldMountSetupTab(.overlays) {
            retainedTab(.overlays) {
                SettingsView()
                    .frame(maxWidth: 1100, maxHeight: .infinity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func shouldMountSetupTab(_ tab: MainConsoleTab) -> Bool {
        ConsoleModeMountPolicy.shouldMountSetupTab(
            tab,
            consoleMode: viewModel.consoleMode,
            selectedTab: viewModel.selectedMainTab,
            loadedTabs: loadedSetupTabs
        )
    }

    private func markSetupTabLoaded(_ tab: MainConsoleTab) {
        loadedSetupTabs.insert(tab)
    }

    private func trimLoadedSetupTabsForLiveMode() {
        loadedSetupTabs = [viewModel.selectedMainTab]
    }

    @ViewBuilder
    private func retainedTab<Content: View>(_ tab: MainConsoleTab, @ViewBuilder content: () -> Content) -> some View {
        let model = TabRetentionModel(tab: tab, selectedTab: viewModel.selectedMainTab)
        let isSetupModeActive = viewModel.consoleMode == .setup
        if isSetupModeActive {
            content()
                .opacity(model.opacity)
                .allowsHitTesting(model.allowsHitTesting)
                .accessibilityHidden(model.accessibilityHidden)
                .zIndex(model.zIndex)
        } else {
            content()
                .hidden()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .zIndex(model.zIndex)
        }
    }

    private func runDesk() -> some View {
        HStack(alignment: .top, spacing: 12) {
            LeftPanel()
                .frame(width: StudioTheme.directorRailWidth)
                .layoutPriority(1)

            ProgramMonitorView()
                .frame(minWidth: 500, idealWidth: 720, maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(3)

            LiveOpsPanel {
                viewModel.consoleMode = .live
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
            Text(chromeTitle)
                .font(StudioTheme.TypeScale.heading.weight(.black))
                .foregroundStyle(StudioTheme.textPrimary)
                .lineLimit(1)
                .frame(width: 190, alignment: .leading)

            Spacer(minLength: 0)
            panicChromeButton
            Color.clear
                .frame(width: ToolbarLayoutMetrics.panicToModeClusterSpacing, height: 1)
                .accessibilityHidden(true)
            consoleModeCluster
                .layoutPriority(1)
            Spacer(minLength: 16)
            MainToolbar(
                embedded: true,
                consoleMode: viewModel.consoleMode,
                onOpenPreview: { viewModel.navigateToSetup(.preview) },
                onOpenAudioMixer: { viewModel.navigateToSetup(.audioMixer) },
                onOpenOverlays: { viewModel.navigateToSetup(.overlays) }
            )
                .layoutPriority(2)
        }
        .padding(.horizontal, 18)
        .padding(.top, ConsoleChromeLayoutMetrics.navigationBarTopPadding)
        .padding(.bottom, ConsoleChromeLayoutMetrics.navigationBarBottomPadding)
        .frame(minHeight: ConsoleChromeLayoutMetrics.navigationBarMinHeight)
        .background(StudioTheme.Surface.base.opacity(0.55))
        .overlay(Divider(), alignment: .bottom)
    }

    private var panicChromeButton: some View {
        PanicChromeButton(
            model: PanicButtonModel.make(
                isActive: viewModel.isPanicMode,
                consoleMode: viewModel.consoleMode
            ),
            isActive: viewModel.isPanicMode
        ) {
            togglePanic()
        }
    }

    @MainActor
    private func togglePanic() {
        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel.togglePanicMode()
        }
    }

    private var chromeTitle: String {
        viewModel.consoleMode == .live ? "LiveSwitcher · LIVE" : viewModel.selectedMainTab.chromeTitle
    }

    private var consoleModeCluster: some View {
        HStack(spacing: 6) {
            setupModeControl
            NavigationTabButton(
                title: ConsoleMode.live.displayTitle,
                systemImage: ConsoleMode.live.systemImage,
                isSelected: viewModel.consoleMode == .live
            ) {
                viewModel.consoleMode = .live
            }
        }
        .padding(5)
        .background(Capsule(style: .continuous).fill(StudioTheme.Surface.base))
        .overlay(Capsule(style: .continuous).stroke(StudioTheme.borderSubtle, lineWidth: 1))
    }

    @ViewBuilder
    private var setupModeControl: some View {
        if viewModel.consoleMode == .setup {
            setupModeMenuButton
        } else {
            NavigationTabButton(
                title: "准备",
                systemImage: "chevron.left",
                isSelected: false
            ) {
                viewModel.navigateToSetup(viewModel.selectedMainTab)
            }
            .accessibilityHint("返回准备模式")
        }
    }

    private var setupModeMenuButton: some View {
        Menu {
            ForEach(MainConsoleTab.allCases, id: \.self) { tab in
                Button {
                    viewModel.navigateToSetup(tab)
                } label: {
                    Label(tab.setupMenuShortcutLabel, systemImage: tab.systemImage)
                }
                .keyboardShortcut(KeyEquivalent(Character(tab.setupShortcutKey)), modifiers: .command)
                .disabled(tab == viewModel.selectedMainTab)
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: ConsoleMode.setup.systemImage)
                    .font(StudioTheme.TypeScale.body.weight(.semibold))
                    .accessibilityHidden(true)
                Text("\(ConsoleMode.setup.displayTitle): \(viewModel.selectedMainTab.setupMenuTitle)")
                    .font(StudioTheme.TypeScale.heading.weight(.bold))
                Image(systemName: "chevron.down")
                    .font(StudioTheme.TypeScale.label.weight(.black))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: StudioTheme.controlHeightL)
            .background(Capsule(style: .continuous).fill(StudioTheme.Action.primary))
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .focusable(false)
        .accessibilityLabel("准备模式")
        .accessibilityValue(viewModel.selectedMainTab.setupMenuTitle)
        .accessibilityHint("选择准备页面")
    }
}

// MARK: - V21 Fix #3: 全局键盘监听器（NSEvent.addLocalMonitorForEvents 可靠拦截字符键）

@MainActor
struct GlobalKeyMonitor: NSViewRepresentable {
    var viewModel: SwitcherViewModel

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
        // MARK: - Tier1: ⌘⌥B -> 紧急切黑 (handled before modifiers guard)
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

// MARK: - Preview

#Preview {
    ContentView()
        .environment(SwitcherViewModel())
}
