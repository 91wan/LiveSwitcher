import SwiftUI

@MainActor
struct PrimaryNavigationBar: View {
    let title: String
    let consoleMode: ConsoleMode
    let selectedTab: MainConsoleTab
    let isPanicMode: Bool
    let onTogglePanic: @MainActor () -> Void
    let onNavigateToSetup: @MainActor (MainConsoleTab) -> Void
    let onEnterLive: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(StudioTheme.TypeScale.title.weight(.black))
                .foregroundStyle(StudioTheme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(minWidth: 220, idealWidth: 280, maxWidth: 340, alignment: .leading)
                .help(title)

            Spacer(minLength: 0)
            PanicChromeContainer(
                isPanicMode: isPanicMode,
                consoleMode: consoleMode,
                onTogglePanic: onTogglePanic
            )
            Color.clear
                .frame(width: ToolbarLayoutMetrics.panicToModeClusterSpacing, height: 1)
                .accessibilityHidden(true)
            ConsoleModeCluster(
                consoleMode: consoleMode,
                selectedTab: selectedTab,
                onNavigateToSetup: onNavigateToSetup,
                onEnterLive: onEnterLive
            )
            .layoutPriority(1)
            Spacer(minLength: 16)
            MainToolbar(
                embedded: true,
                consoleMode: consoleMode,
                onOpenPreview: { onNavigateToSetup(.preview) },
                onOpenAudioMixer: { onNavigateToSetup(.audioMixer) },
                onOpenOverlays: { onNavigateToSetup(.overlays) }
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
}
