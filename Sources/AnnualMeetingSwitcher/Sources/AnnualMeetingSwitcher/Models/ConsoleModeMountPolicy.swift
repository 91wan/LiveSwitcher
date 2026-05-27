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

        return tab == selectedTab && loadedTabs.contains(tab)
    }

    static func shouldMountSetupLayer(
        consoleMode: ConsoleMode,
        selectedTab: MainConsoleTab,
        loadedTabs: Set<MainConsoleTab>
    ) -> Bool {
        consoleMode == .setup || loadedTabs.contains(selectedTab)
    }

    static func shouldMountLiveLayer(consoleMode: ConsoleMode) -> Bool {
        consoleMode == .live
    }

    static func shouldMountLiveLayer(
        consoleMode: ConsoleMode,
        hasMountedLiveLayer: Bool
    ) -> Bool {
        consoleMode == .live || hasMountedLiveLayer
    }
}
