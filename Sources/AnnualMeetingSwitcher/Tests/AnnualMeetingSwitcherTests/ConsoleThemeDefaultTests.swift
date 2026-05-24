import XCTest
@testable import LiveSwitcher

@MainActor
final class ConsoleThemeDefaultTests: XCTestCase {
    func testFirstLaunchDefaultsToDarkConsoleTheme() {
        let suite = "ConsoleThemeDefault-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            XCTFail("Could not create isolated defaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.removeObject(forKey: "themeOverride")

        let viewModel = SwitcherViewModel(
            loadPersistedData: true,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )

        XCTAssertEqual(viewModel.themeOverride, .dark)
        XCTAssertEqual(viewModel.themeOverride.colorScheme, .dark)
    }
}
