import XCTest
@testable import LiveSwitcher

@MainActor
final class AppLaunchPolicyTests: XCTestCase {
    func testApplicationIdentityConfigurationMatchesReleaseContract() {
        XCTAssertEqual(AppConfiguration.appName, "LiveSwitcher")
        XCTAssertEqual(AppConfiguration.appVersion, "0.5.0")
        XCTAssertEqual(AppConfiguration.bundleIdentifier, "com.91wan.liveswitcher")
        XCTAssertEqual(AppConfiguration.wpsBundleIdentifier, "com.kingsoft.wpsoffice.mac")
        XCTAssertEqual(AppConfiguration.minWindowWidth, 1360)
        XCTAssertEqual(AppConfiguration.minWindowHeight, 700)
    }

    func testLaunchCoordinatorRetainsSharedViewModelUntilFallbackCanUseIt() {
        weak var weakViewModel: SwitcherViewModel?

        do {
            let viewModel = SwitcherViewModel(
                loadPersistedData: false,
                enableSystemVolumeObserver: false,
                userDefaults: isolatedDefaults()
            )
            weakViewModel = viewModel
            LiveSwitcherLaunchCoordinator.sharedViewModel = viewModel
        }

        defer { LiveSwitcherLaunchCoordinator.sharedViewModel = nil }
        XCTAssertNotNil(weakViewModel)
    }

    func testFallbackWindowOwnershipModelSeparatesWindowGroupFallbackAndLegacyTitle() {
        XCTAssertEqual(
            MainWindowFallbackPolicy.origin(identifier: "main-console-AppWindow-1", title: "LiveSwitcher"),
            .windowGroup
        )
        XCTAssertEqual(
            MainWindowFallbackPolicy.origin(identifier: "main-console-fallback", title: "LiveSwitcher"),
            .fallback
        )
        XCTAssertEqual(
            MainWindowFallbackPolicy.origin(identifier: nil, title: "LiveSwitcher"),
            .legacyTitleMatch
        )
    }

    func testFallbackWindowPolicyDoesNotClaimImportOrOutputUtilityWindows() {
        XCTAssertNil(MainWindowFallbackPolicy.origin(identifier: "import-panel", title: "导入节目"))
        XCTAssertNil(MainWindowFallbackPolicy.origin(identifier: "output-window", title: "LiveSwitcher Output"))
        XCTAssertNil(MainWindowFallbackPolicy.origin(identifier: nil, title: "LiveSwitcher Output"))
        XCTAssertNil(MainWindowFallbackPolicy.origin(identifier: nil, title: "Other Window"))
    }

    func testVisibleOccludedMainWindowIsReusable() {
        XCTAssertTrue(
            MainWindowFallbackPolicy.shouldReuseMainWindow(
                isVisible: true,
                isMiniaturized: false,
                isOcclusionVisible: false
            )
        )
    }

    func testHiddenOrMiniaturizedMainWindowIsNotReusableUntilOrderedFront() {
        XCTAssertFalse(
            MainWindowFallbackPolicy.shouldReuseMainWindow(
                isVisible: false,
                isMiniaturized: false,
                isOcclusionVisible: false
            )
        )
        XCTAssertFalse(
            MainWindowFallbackPolicy.shouldReuseMainWindow(
                isVisible: true,
                isMiniaturized: true,
                isOcclusionVisible: true
            )
        )
    }

    func testAnyUnusableMainWindowMayBeClosedAfterReorderFails() {
        XCTAssertTrue(MainWindowFallbackPolicy.shouldCloseUnusableMainWindow(origin: .windowGroup))
        XCTAssertTrue(MainWindowFallbackPolicy.shouldCloseUnusableMainWindow(origin: .legacyTitleMatch))
        XCTAssertTrue(MainWindowFallbackPolicy.shouldCloseUnusableMainWindow(origin: .fallback))
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "AppLaunchPolicyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
