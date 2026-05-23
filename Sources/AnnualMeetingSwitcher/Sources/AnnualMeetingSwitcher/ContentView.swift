import SwiftUI

// MARK: - Main view

struct ContentView: View {
    @EnvironmentObject var viewModel: SwitcherViewModel

    var body: some View {
        VStack(spacing: 0) {
            primaryNavigationBar
            LiveStatusStrip(model: liveStatusModel)

            mainContent
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

            retainedTab(.preview) {
                runDesk
            }

            retainedTab(.audioMixer) {
                AudioMixerView()
                    .frame(maxWidth: 940, maxHeight: .infinity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            retainedTab(.overlays) {
                SettingsView()
                    .frame(maxWidth: 1100, maxHeight: .infinity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func retainedTab<Content: View>(_ tab: MainConsoleTab, @ViewBuilder content: () -> Content) -> some View {
        let model = TabRetentionModel(tab: tab, selectedTab: viewModel.selectedMainTab)
        return content()
            .opacity(model.opacity)
            .allowsHitTesting(model.allowsHitTesting)
            .accessibilityHidden(model.accessibilityHidden)
            .zIndex(model.zIndex)
    }

    private var runDesk: some View {
        HStack(alignment: .top, spacing: 12) {
            LeftPanel()
                .frame(width: StudioTheme.directorRailWidth)
                .layoutPriority(1)

            ProgramMonitorView()
                .frame(minWidth: 500, idealWidth: 720, maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(3)

            LiveOpsPanel {
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
            VStack(alignment: .leading, spacing: 2) {
                Text("LiveSwitcher")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(StudioTheme.textPrimary)
                Text("Run Desk")
                    .font(StudioTheme.caption())
                    .foregroundStyle(StudioTheme.textTertiary)
            }
            .frame(width: 132, alignment: .leading)

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
        .background(StudioTheme.surfacePrimary.opacity(0.55))
        .overlay(Divider(), alignment: .bottom)
    }

    private var navigationTabCluster: some View {
        HStack(spacing: 6) {
            navigationTab(title: "导播台", systemName: "play.square.stack.fill", tag: .preview)
            navigationTab(title: "音频", systemName: "slider.horizontal.3", tag: .audioMixer)
            navigationTab(title: "叠层", systemName: "rectangle.3.group.bubble.left.fill", tag: .overlays)
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
            ForEach(Array(model.items.enumerated()), id: \.offset) { index, item in
                statusItem(item, prominent: index == 0)
            }
            Spacer(minLength: StudioTheme.spacingS)
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
        .accessibilityLabel("Live status. \(model.projection.title) \(model.projection.accessibilityValue). \(model.current.title) \(model.current.accessibilityValue). \(model.next.title) \(model.next.accessibilityValue). \(model.audio.title) \(model.audio.accessibilityValue).")
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
        .frame(maxWidth: CGFloat(item.layoutRole.maxWidth))
        .frame(height: 30)
        .background(StudioTheme.statusColor(item.status).opacity(0.08), in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(StudioTheme.statusColor(item.status).opacity(prominent ? 0.26 : 0.14), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title): \(item.accessibilityValue)")
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

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(SwitcherViewModel())
}
