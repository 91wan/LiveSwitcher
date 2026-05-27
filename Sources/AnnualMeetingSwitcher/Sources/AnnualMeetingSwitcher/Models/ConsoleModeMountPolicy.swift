import Foundation

enum ConsoleModeMountPolicy {
    static func shouldMountSetupTab(
        _ tab: MainConsoleTab,
        consoleMode: ConsoleMode,
        selectedTab: MainConsoleTab,
        loadedTabs: Set<MainConsoleTab>
    ) -> Bool {
        if consoleMode == .setup {
            return tab == selectedTab || loadedTabs.contains(tab)
        }

        return false
    }

    static func shouldMountSetupLayer(
        consoleMode: ConsoleMode,
        selectedTab: MainConsoleTab,
        loadedTabs: Set<MainConsoleTab>
    ) -> Bool {
        consoleMode == .setup
    }

    static func shouldMountLiveLayer(consoleMode: ConsoleMode) -> Bool {
        consoleMode == .live
    }
}
