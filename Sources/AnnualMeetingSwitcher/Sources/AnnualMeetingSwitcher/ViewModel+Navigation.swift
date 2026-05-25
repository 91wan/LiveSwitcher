import Foundation

@MainActor
extension SwitcherViewModel {
    func navigateToSetup(_ tab: MainConsoleTab) {
        consoleMode = .setup
        selectedMainTab = tab
    }
}
