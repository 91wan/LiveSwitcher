import XCTest
@testable import LiveSwitcher

final class ConsoleNavigationTests: XCTestCase {
    @MainActor
    func testNavigateToSetupSwitchesOutOfLiveModeAndSelectsTargetTab() {
        let suiteName = "ConsoleNavigationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
        viewModel.consoleMode = .live
        viewModel.selectedMainTab = .preview

        viewModel.navigateToSetup(.audioMixer)

        XCTAssertEqual(viewModel.consoleMode, .setup)
        XCTAssertEqual(viewModel.selectedMainTab, .audioMixer)
    }

    func testContentViewLiveMixerCallbackUsesSetupNavigationHelper() throws {
        let source = try sourceText("ContentView.swift")

        XCTAssertTrue(source.contains("LiveModeView"))
        XCTAssertTrue(source.contains("viewModel.navigateToSetup(.audioMixer)"))
        XCTAssertFalse(source.contains("LiveModeView {\n                            viewModel.selectedMainTab = .audioMixer"))
    }

    func testLiveModeSetupButtonsUseSetupNavigationHelper() throws {
        let source = try sourceText("Views/LiveModeView.swift")

        XCTAssertTrue(source.contains("viewModel.navigateToSetup(.preview)"))
        XCTAssertTrue(source.contains("viewModel.navigateToSetup(.overlays)"))
        XCTAssertFalse(source.contains("viewModel.consoleMode = .setup\n                            viewModel.selectedMainTab = .preview"))
        XCTAssertFalse(source.contains("viewModel.consoleMode = .setup\n            viewModel.selectedMainTab = .overlays"))
    }

    func testAppCommandsUseSetupNavigationHelperForTabSwitches() throws {
        let source = try sourceText("App.swift")

        XCTAssertTrue(source.contains("viewModel.navigateToSetup(.preview)"))
        XCTAssertTrue(source.contains("viewModel.navigateToSetup(.audioMixer)"))
        XCTAssertTrue(source.contains("viewModel.navigateToSetup(.overlays)"))
        XCTAssertFalse(source.contains("viewModel.selectedMainTab = ."))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        if isLiveModeViewSourcePath(relativePath) {
            return try liveModeSourceTextAggregate(repositoryRoot: repositoryRoot(filePath: #filePath))
        }
        return try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
