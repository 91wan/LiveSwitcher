import Foundation

enum ConsoleModeMountPolicy {
    static func shouldMountSetupTab(
        _ tab: MainConsoleTab,
        consoleMode: ConsoleMode,
        selectedTab: MainConsoleTab,
        loadedTabs: Set<MainConsoleTab>
    ) -> Bool {
        guard consoleMode == .setup else { return false }
        return tab == selectedTab || loadedTabs.contains(tab)
    }

    static func shouldMountLiveLayer(consoleMode: ConsoleMode) -> Bool {
        consoleMode == .live
    }
}
