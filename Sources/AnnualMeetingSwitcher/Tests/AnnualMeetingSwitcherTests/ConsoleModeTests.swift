import XCTest
@testable import LiveSwitcher

final class ConsoleModeTests: XCTestCase {
    func testConsoleModeCasesUseStablePersistenceAndLocalizationKeys() {
        XCTAssertEqual(ConsoleMode.setup.rawValue, "setup")
        XCTAssertEqual(ConsoleMode.live.rawValue, "live")
        XCTAssertEqual(ConsoleMode.allCases, [.setup, .live])
        XCTAssertEqual(ConsoleMode.setup.displayTitleKey, "console.mode.setup")
        XCTAssertEqual(ConsoleMode.live.displayTitleKey, "console.mode.live")
        XCTAssertEqual(ConsoleMode.setup.systemImage, "gearshape.fill")
        XCTAssertEqual(ConsoleMode.live.systemImage, "play.fill")
    }

    func testConsoleModeLocalizationResourcesExistForEnglishAndChinese() throws {
        let english = try sourceText("Resources/en.lproj/Localizable.strings")
        let chinese = try sourceText("Resources/zh-Hans.lproj/Localizable.strings")

        XCTAssertTrue(english.contains("\"console.mode.setup\" = \"Setup\";"))
        XCTAssertTrue(english.contains("\"console.mode.live\" = \"Live\";"))
        XCTAssertTrue(chinese.contains("\"console.mode.setup\" = \"准备\";"))
        XCTAssertTrue(chinese.contains("\"console.mode.live\" = \"现场\";"))
    }

    @MainActor
    func testViewModelDefaultsToSetupAndPersistsConsoleMode() {
        let suiteName = "ConsoleModeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
        XCTAssertEqual(viewModel.consoleMode, .setup)

        viewModel.consoleMode = .live
        let restored = SwitcherViewModel(loadPersistedData: true, enableSystemVolumeObserver: false, userDefaults: defaults)
        XCTAssertEqual(restored.consoleMode, .live)
    }

    func testContentViewUsesModeSwitcherAndKeepsSetupTabsScopedToSetupMode() throws {
        let source = try sourceText("ContentView.swift")

        XCTAssertTrue(source.contains("consoleModeCluster"))
        XCTAssertTrue(source.contains("setupTabCluster"))
        XCTAssertTrue(source.contains("viewModel.consoleMode == .setup"))
        XCTAssertTrue(source.contains("activeContentTab"))
    }

    func testLiveModeRoutesRunDeskPanelsWithLiveFlag() throws {
        let content = try sourceText("ContentView.swift")
        let leftPanel = try sourceText("Views/LeftPanel.swift")
        let monitor = try sourceText("Views/ProgramMonitorView.swift")
        let toolbar = try sourceText("Views/MainToolbar.swift")

        XCTAssertTrue(content.contains("runDesk(isLiveMode:"))
        XCTAssertTrue(leftPanel.contains("var isLiveMode: Bool"))
        XCTAssertTrue(leftPanel.contains("if !isLiveMode"))
        XCTAssertTrue(monitor.contains("var isLiveMode: Bool"))
        XCTAssertTrue(monitor.contains("if !isLiveMode"))
        XCTAssertTrue(toolbar.contains("var consoleMode: ConsoleMode"))
    }

    func testModeMenuDefinesSetupAndLiveKeyboardShortcuts() throws {
        let app = try sourceText("App.swift")

        XCTAssertTrue(app.contains("CommandMenu(\"Mode\")"))
        XCTAssertTrue(app.contains("viewModel.consoleMode = .setup"))
        XCTAssertTrue(app.contains("viewModel.consoleMode = .live"))
        XCTAssertTrue(app.contains(".keyboardShortcut(\"s\", modifiers: [.command, .shift])"))
        XCTAssertTrue(app.contains(".keyboardShortcut(\"l\", modifiers: [.command, .shift])"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let directCandidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: directCandidate.path) {
                return directCandidate
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }
}
