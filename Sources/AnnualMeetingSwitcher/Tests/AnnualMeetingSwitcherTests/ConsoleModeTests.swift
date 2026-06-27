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
        XCTAssertTrue(source.contains("setupContentTabs"))
        XCTAssertFalse(source.contains("activeContentTab"))
        XCTAssertFalse(source.contains("Image(systemName: \"ellipsis\")"))
    }

    func testLiveModeRoutesDedicatedLayoutInsteadOfSetupRunDesk() throws {
        let content = try sourceText("ContentView.swift")
        let leftPanel = try sourceText("Views/LeftPanel.swift")
        let monitor = try sourceText("Views/ProgramMonitor/ProgramMonitorView.swift")
        let toolbar = try sourceText("Views/MainToolbar.swift")

        XCTAssertTrue(content.contains("LiveModeView"))
        XCTAssertTrue(content.contains("runDesk()"))
        XCTAssertFalse(content.contains("runDesk(isLiveMode:"))
        XCTAssertFalse(leftPanel.contains("var isLiveMode: Bool"))
        XCTAssertTrue(monitor.contains("var isLiveMode: Bool"))
        XCTAssertTrue(monitor.contains("if !isLiveMode"))
        XCTAssertTrue(toolbar.contains("var consoleMode: ConsoleMode"))
    }

    func testLiveModeDoesNotMountInactiveSetupTabsDuringModeSwitch() throws {
        let content = try sourceText("ContentView.swift")

        XCTAssertTrue(content.contains("setupContentTabs"))
        XCTAssertTrue(content.contains("liveContent"))
        XCTAssertFalse(content.contains("hasMountedLiveMode"))
        XCTAssertFalse(content.contains("prewarmLiveModeLayer"))
        XCTAssertTrue(content.contains("ConsoleModeMountPolicy.shouldMountSetupLayer("))
        XCTAssertTrue(content.contains("ConsoleModeMountPolicy.shouldMountLiveLayer("))
        XCTAssertFalse(content.contains("consoleModeRetainedLayer(isActive: viewModel.consoleMode == .setup)"))
        XCTAssertTrue(content.contains("activeConsoleLayer(isActive: viewModel.consoleMode == .live)"))
        XCTAssertFalse(content.contains("retainedTab(.preview) {\n                    if viewModel.consoleMode == .live"))
        XCTAssertFalse(content.contains("activeContentTab"))
    }

    func testSetupTabsMountLazilyToAvoidLiveSetupSwitchStalls() throws {
        let content = try sourceText("ContentView.swift")

        XCTAssertTrue(content.contains("@State private var loadedSetupTabs"))
        XCTAssertTrue(content.contains("shouldMountSetupTab(.audioMixer)"))
        XCTAssertTrue(content.contains("shouldMountSetupTab(.overlays)"))
        XCTAssertTrue(content.contains("markSetupTabLoaded"))
        XCTAssertTrue(content.contains("trimLoadedSetupTabsForLiveMode"))
    }

    func testSetupLayerUnmountsWhileLiveModeIsActive() throws {
        let content = try sourceText("ContentView.swift")

        XCTAssertFalse(ConsoleModeMountPolicy.shouldMountSetupLayer(
            consoleMode: .live,
            selectedTab: .preview,
            loadedTabs: [.preview]
        ))
        XCTAssertTrue(content.contains("ConsoleModeMountPolicy.shouldMountSetupLayer("))
        XCTAssertFalse(content.contains("consoleModeRetainedLayer(isActive: viewModel.consoleMode == .setup)"))
    }

    func testSetupTabsUnmountWhileLiveModeIsActive() {
        let loaded: Set<MainConsoleTab> = [.preview, .audioMixer, .overlays]

        XCTAssertFalse(ConsoleModeMountPolicy.shouldMountSetupTab(
            .preview,
            consoleMode: .live,
            selectedTab: .preview,
            loadedTabs: loaded
        ))
        XCTAssertFalse(ConsoleModeMountPolicy.shouldMountSetupTab(
            .audioMixer,
            consoleMode: .live,
            selectedTab: .preview,
            loadedTabs: loaded
        ))
        XCTAssertTrue(ConsoleModeMountPolicy.shouldMountSetupTab(
            .audioMixer,
            consoleMode: .setup,
            selectedTab: .preview,
            loadedTabs: loaded
        ))
        XCTAssertFalse(ConsoleModeMountPolicy.shouldMountSetupLayer(
            consoleMode: .live,
            selectedTab: .preview,
            loadedTabs: [.preview]
        ))
        XCTAssertTrue(ConsoleModeMountPolicy.shouldMountSetupLayer(
            consoleMode: .setup,
            selectedTab: .preview,
            loadedTabs: [.preview]
        ))
    }

    func testLiveModeLayerUnmountsWhileSetupIsActiveToAvoidHiddenHeavyView() throws {
        let content = try sourceText("ContentView.swift")
        let policy = try sourceText("Models/ConsoleModeMountPolicy.swift")

        XCTAssertTrue(ConsoleModeMountPolicy.shouldMountLiveLayer(consoleMode: .live))
        XCTAssertFalse(ConsoleModeMountPolicy.shouldMountLiveLayer(consoleMode: .setup))
        XCTAssertFalse(content.contains("hasMountedLiveMode"))
        XCTAssertFalse(policy.contains("hasMountedLiveLayer"))
        XCTAssertFalse(content.contains("prewarmLiveModeLayer"))
    }

    func testConsoleModeSwitchesAvoidWholeLayoutAnimation() throws {
        let content = try sourceText("ContentView.swift")

        XCTAssertFalse(content.contains("withAnimation(.easeInOut(duration: 0.16)) {\n                    viewModel.consoleMode = .live"))
        XCTAssertFalse(content.contains("withAnimation(.easeInOut(duration: 0.16)) {\n                    viewModel.navigateToSetup(viewModel.selectedMainTab)"))
    }

    func testLiveReturnToSetupButtonDoesNotDuplicateBackArrowCopy() throws {
        let content = try sourceText("ContentView.swift")

        XCTAssertTrue(content.contains("title: \"准备\""))
        XCTAssertTrue(content.contains("systemImage: \"chevron.left\""))
        XCTAssertFalse(content.contains("title: \"← 准备\""))
    }

    func testInactiveRetainedConsoleLayerIsHiddenInsteadOfTransparentRendered() throws {
        let content = try sourceText("ContentView.swift")

        XCTAssertTrue(content.contains("if isActive {"))
        XCTAssertTrue(content.contains(".hidden()"))
        XCTAssertFalse(content.contains(".opacity(isActive ? 1 : 0)"))
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
        try LiveSwitcherTests.sourceText(relativePath, filePath: #filePath)
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
