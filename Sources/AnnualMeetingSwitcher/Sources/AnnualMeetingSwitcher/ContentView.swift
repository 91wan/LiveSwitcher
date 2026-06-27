import SwiftUI

// MARK: - Main view

@MainActor
struct ContentView: View {
    @Environment(SwitcherViewModel.self) var viewModel
    @Environment(\.openWindow) private var openWindow
    @State private var loadedSetupTabs: Set<MainConsoleTab> = [.preview]

    var body: some View {
        VStack(spacing: 0) {
            ConsoleChromeView(
                title: chromeTitle,
                consoleMode: viewModel.consoleMode,
                selectedTab: viewModel.selectedMainTab,
                isPanicMode: viewModel.isPanicMode,
                automationNotice: viewModel.automationRuntimeNotice,
                onTogglePanic: togglePanic,
                onNavigateToSetup: { tab in
                    viewModel.navigateToSetup(tab)
                },
                onEnterLive: {
                    viewModel.consoleMode = .live
                },
                onNoticePrimaryAction: { action in
                    handleAutomationRuntimeNoticeAction(action)
                },
                onNoticeDismiss: {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        viewModel.dismissAutomationRuntimeNotice()
                    }
                },
                onNoticeExpire: { notice in
                    await expireAutomationRuntimeNotice(notice)
                }
            )
            ConsoleMainContent(
                consoleMode: viewModel.consoleMode,
                selectedTab: viewModel.selectedMainTab,
                loadedSetupTabs: loadedSetupTabs,
                avCoordinator: viewModel.avCoordinator,
                onNavigateToSetup: { tab in
                    viewModel.navigateToSetup(tab)
                },
                onEnterLive: {
                    viewModel.consoleMode = .live
                }
            )
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
            let profile = ConsoleModeSwitchProfiler.begin(targetMode: newMode)
            if newMode == .setup {
                markSetupTabLoaded(viewModel.selectedMainTab)
            } else {
                trimLoadedSetupTabsForLiveMode()
            }
            finishConsoleModeSwitch(profile)
        }
    }

    private func markSetupTabLoaded(_ tab: MainConsoleTab) {
        loadedSetupTabs.insert(tab)
    }

    private func trimLoadedSetupTabsForLiveMode() {
        loadedSetupTabs = [viewModel.selectedMainTab]
    }

    private func finishConsoleModeSwitch(_ profile: ConsoleModeSwitchProfiler.Start) {
        Task { @MainActor in
            await Task.yield()
            guard viewModel.consoleMode == profile.targetMode else { return }
            let event = ConsoleModeSwitchProfiler.end(profile)
            ConsoleModeSwitchProfiler.log(event)
            if let detail = event.supportEventDetail {
                viewModel.recordSupportEvent(kind: .consoleModeSwitchSlow, detail: detail)
            }
        }
    }

    @MainActor
    private func togglePanic() {
        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel.togglePanicMode()
        }
    }

    private var chromeTitle: String {
        ConsoleBrandingModel.title(
            brandName: viewModel.companyDisplayName,
            mode: viewModel.consoleMode,
            tab: viewModel.selectedMainTab
        )
    }

    @MainActor
    private func expireAutomationRuntimeNotice(_ notice: AutomationRuntimeNotice) async {
        guard let expiresAt = notice.expiresAt else { return }
        let delay = max(0, expiresAt.timeIntervalSinceNow)
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.16)) {
            viewModel.expireAutomationRuntimeNotice(id: notice.id)
        }
    }

    @MainActor
    private func handleAutomationRuntimeNoticeAction(_ action: AutomationRuntimeNoticeAction) {
        switch action {
        case .openSafetyCockpit:
            openWindow(id: "safety-cockpit")
        case .openHelp:
            viewModel.navigateToSetup(.preview)
        case .openSystemSettingsAccessibility:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
        viewModel.dismissAutomationRuntimeNotice()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(SwitcherViewModel())
}
