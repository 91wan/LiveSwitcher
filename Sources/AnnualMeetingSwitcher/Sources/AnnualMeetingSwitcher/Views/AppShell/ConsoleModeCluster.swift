import SwiftUI

@MainActor
struct ConsoleModeCluster: View {
    let consoleMode: ConsoleMode
    let selectedTab: MainConsoleTab
    let onNavigateToSetup: @MainActor (MainConsoleTab) -> Void
    let onEnterLive: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 6) {
            setupModeControl
            NavigationTabButton(
                title: ConsoleMode.live.displayTitle,
                systemImage: ConsoleMode.live.systemImage,
                isSelected: consoleMode == .live
            ) {
                onEnterLive()
            }
        }
        .padding(5)
        .background(Capsule(style: .continuous).fill(StudioTheme.Surface.base))
        .overlay(Capsule(style: .continuous).stroke(StudioTheme.borderSubtle, lineWidth: 1))
    }

    @ViewBuilder
    private var setupModeControl: some View {
        if consoleMode == .setup {
            setupModeMenuButton
        } else {
            NavigationTabButton(
                title: "准备",
                systemImage: "chevron.left",
                isSelected: false
            ) {
                onNavigateToSetup(selectedTab)
            }
            .accessibilityHint("返回准备模式")
        }
    }

    private var setupModeMenuButton: some View {
        Menu {
            ForEach(MainConsoleTab.allCases, id: \.self) { tab in
                Button {
                    onNavigateToSetup(tab)
                } label: {
                    Label(tab.setupMenuShortcutLabel, systemImage: tab.systemImage)
                }
                .keyboardShortcut(KeyEquivalent(Character(tab.setupShortcutKey)), modifiers: .command)
                .disabled(tab == selectedTab)
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: ConsoleMode.setup.systemImage)
                    .font(StudioTheme.TypeScale.body.weight(.semibold))
                    .accessibilityHidden(true)
                Text("\(ConsoleMode.setup.displayTitle): \(selectedTab.setupMenuTitle)")
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
        .accessibilityValue(selectedTab.setupMenuTitle)
        .accessibilityHint("选择准备页面")
    }
}
