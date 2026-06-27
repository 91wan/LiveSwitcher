import SwiftUI

@MainActor
struct ConsoleMainContent: View {
    let consoleMode: ConsoleMode
    let selectedTab: MainConsoleTab
    let loadedSetupTabs: Set<MainConsoleTab>
    let avCoordinator: AVPlayerCoordinator
    let onNavigateToSetup: @MainActor (MainConsoleTab) -> Void
    let onEnterLive: @MainActor () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                StudioTheme.canvasGradient
                    .ignoresSafeArea()

                if ConsoleModeMountPolicy.shouldMountSetupLayer(
                    consoleMode: consoleMode,
                    selectedTab: selectedTab,
                    loadedTabs: loadedSetupTabs
                ) {
                    setupContentTabs
                }

                if ConsoleModeMountPolicy.shouldMountLiveLayer(consoleMode: consoleMode) {
                    ActiveConsoleLayer(isActive: consoleMode == .live) {
                        liveContent
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if SetupAudioDockModel.shouldShow(consoleMode: consoleMode, selectedTab: selectedTab) {
                SetupAudioDock {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        onNavigateToSetup(.audioMixer)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var liveContent: some View {
        LiveModeView {
            onNavigateToSetup(.audioMixer)
        }
    }

    @ViewBuilder
    private var setupContentTabs: some View {
        if shouldMountSetupTab(.preview) {
            retainedTab(.preview) {
                RunDeskLayout(avCoordinator: avCoordinator, onEnterLive: onEnterLive)
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
            consoleMode: consoleMode,
            selectedTab: selectedTab,
            loadedTabs: loadedSetupTabs
        )
    }

    @ViewBuilder
    private func retainedTab<Content: View>(_ tab: MainConsoleTab, @ViewBuilder content: () -> Content) -> some View {
        let model = TabRetentionModel(tab: tab, selectedTab: selectedTab)
        let isSetupModeActive = consoleMode == .setup
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
}

@MainActor
struct ActiveConsoleLayer<Content: View>: View {
    let isActive: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
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
}
