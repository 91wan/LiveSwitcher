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

    func testConsoleModeLocalizationResourcesKeepChineseConsoleCopyAcrossBundles() throws {
        let english = try sourceText("Resources/en.lproj/Localizable.strings")
        let chinese = try sourceText("Resources/zh-Hans.lproj/Localizable.strings")

        XCTAssertTrue(english.contains("\"console.mode.setup\" = \"准备\";"))
        XCTAssertTrue(english.contains("\"console.mode.live\" = \"现场\";"))
        XCTAssertFalse(english.contains("\"console.mode.setup\" = \"Setup\";"))
        XCTAssertFalse(english.contains("\"console.mode.live\" = \"Live\";"))
        XCTAssertTrue(chinese.contains("\"console.mode.setup\" = \"准备\";"))
        XCTAssertTrue(chinese.contains("\"console.mode.live\" = \"现场\";"))
    }

    func testSetupTabsExposeCompactNavigationMetadata() {
        XCTAssertEqual(MainConsoleTab.preview.setupMenuTitle, "节目单")
        XCTAssertEqual(MainConsoleTab.preview.setupMenuShortcutLabel, "节目单  ⌘1")
        XCTAssertEqual(MainConsoleTab.preview.setupShortcutKey, "1")
        XCTAssertEqual(MainConsoleTab.preview.systemImage, "play.square.stack.fill")
        XCTAssertEqual(MainConsoleTab.audioMixer.setupMenuTitle, "音频")
        XCTAssertEqual(MainConsoleTab.audioMixer.setupMenuShortcutLabel, "音频  ⌘2")
        XCTAssertEqual(MainConsoleTab.audioMixer.setupShortcutKey, "2")
        XCTAssertEqual(MainConsoleTab.audioMixer.systemImage, "slider.horizontal.3")
        XCTAssertEqual(MainConsoleTab.overlays.setupMenuTitle, "叠层")
        XCTAssertEqual(MainConsoleTab.overlays.setupMenuShortcutLabel, "叠层  ⌘3")
        XCTAssertEqual(MainConsoleTab.overlays.setupShortcutKey, "3")
        XCTAssertEqual(MainConsoleTab.overlays.systemImage, "rectangle.3.group.bubble.left.fill")
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
        XCTAssertTrue(source.contains("setupModeMenuButton"))
        XCTAssertFalse(source.contains("setupTabCluster"))
        XCTAssertFalse(source.contains("navigationTab("))
        XCTAssertTrue(source.contains("viewModel.consoleMode == .setup"))
        XCTAssertTrue(source.contains("activeContentTab"))
        XCTAssertFalse(source.contains("Image(systemName: \"ellipsis\")"))
    }

    func testLiveModeRoutesDedicatedLayoutInsteadOfSetupRunDesk() throws {
        let content = try sourceText("ContentView.swift")
        let leftPanel = try sourceText("Views/LeftPanel.swift")
        let monitor = try sourceText("Views/ProgramMonitorView.swift")
        let toolbar = try sourceText("Views/MainToolbar.swift")

        XCTAssertTrue(content.contains("LiveModeView"))
        XCTAssertTrue(content.contains("runDesk()"))
        XCTAssertFalse(content.contains("runDesk(isLiveMode:"))
        XCTAssertFalse(leftPanel.contains("var isLiveMode: Bool"))
        XCTAssertTrue(monitor.contains("var isLiveMode: Bool"))
        XCTAssertTrue(monitor.contains("if !isLiveMode"))
        XCTAssertTrue(toolbar.contains("var consoleMode: ConsoleMode"))
    }

    func testModeMenuDefinesSetupAndLiveKeyboardShortcuts() throws {
        let app = try sourceText("App.swift")

        XCTAssertTrue(app.contains("CommandMenu(\"模式\")"))
        XCTAssertTrue(app.contains("viewModel.consoleMode = .setup"))
        XCTAssertTrue(app.contains("viewModel.consoleMode = .live"))
        XCTAssertTrue(app.contains(".keyboardShortcut(\"s\", modifiers: [.command, .shift])"))
        XCTAssertTrue(app.contains(".keyboardShortcut(\"l\", modifiers: [.command, .shift])"))
    }

    func testSetupMenuExposesDiscoverableTabShortcuts() throws {
        let content = try sourceText("ContentView.swift")
        let app = try sourceText("App.swift")

        XCTAssertTrue(content.contains("tab.setupMenuShortcutLabel"))
        XCTAssertTrue(content.contains(".keyboardShortcut(KeyEquivalent(Character(tab.setupShortcutKey)), modifiers: .command)"))
        XCTAssertFalse(content.contains("ellipsis"))

        XCTAssertTrue(app.contains("CommandMenu(\"准备页面\")"))
        XCTAssertTrue(app.contains("viewModel.navigateToSetup(.preview)"))
        XCTAssertTrue(app.contains("viewModel.navigateToSetup(.audioMixer)"))
        XCTAssertTrue(app.contains("viewModel.navigateToSetup(.overlays)"))
        XCTAssertFalse(app.contains("viewModel.selectedMainTab = ."))
        XCTAssertTrue(app.contains(".keyboardShortcut(\"1\", modifiers: .command)"))
        XCTAssertTrue(app.contains(".keyboardShortcut(\"2\", modifiers: .command)"))
        XCTAssertTrue(app.contains(".keyboardShortcut(\"3\", modifiers: .command)"))
    }

    func testMainConsoleUsesAutoPresentedWindowGroup() throws {
        let app = try sourceText("App.swift")

        XCTAssertTrue(app.contains("WindowGroup(\"LiveSwitcher\", id: \"main-console\")"))
        XCTAssertTrue(app.contains("Window(\"现场安全台\", id: \"safety-cockpit\")"))
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
