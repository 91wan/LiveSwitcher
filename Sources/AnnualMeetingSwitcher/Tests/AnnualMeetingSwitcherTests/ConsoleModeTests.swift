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
        let content = try sourceText("ContentView.swift")
        let modeCluster = try sourceText("Views/AppShell/ConsoleModeCluster.swift")
        let mainContent = try sourceText("Views/AppShell/ActiveConsoleLayer.swift")

        XCTAssertTrue(content.contains("ConsoleChromeView("))
        XCTAssertTrue(modeCluster.contains("struct ConsoleModeCluster"))
        XCTAssertTrue(modeCluster.contains("setupModeMenuButton"))
        XCTAssertFalse(modeCluster.contains("setupTabCluster"))
        XCTAssertFalse(modeCluster.contains("navigationTab("))
        XCTAssertTrue(mainContent.contains("consoleMode == .setup"))
        XCTAssertTrue(mainContent.contains("setupContentTabs"))
        XCTAssertFalse(mainContent.contains("activeContentTab"))
        XCTAssertFalse(modeCluster.contains("Image(systemName: \"ellipsis\")"))
    }

    func testLiveModeRoutesDedicatedLayoutInsteadOfSetupRunDesk() throws {
        let mainContent = try sourceText("Views/AppShell/ActiveConsoleLayer.swift")
        let leftPanel = try sourceText("Views/Setup/LeftPanel.swift")
        let monitor = try sourceText("Views/ProgramMonitor/ProgramMonitorView.swift")
        let toolbar = try sourceText("Views/MainToolbar.swift")

        XCTAssertTrue(mainContent.contains("LiveModeView"))
        XCTAssertTrue(mainContent.contains("RunDeskLayout("))
        XCTAssertFalse(mainContent.contains("runDesk(isLiveMode:"))
        XCTAssertFalse(leftPanel.contains("var isLiveMode: Bool"))
        XCTAssertTrue(monitor.contains("var isLiveMode: Bool"))
        XCTAssertTrue(monitor.contains("if !isLiveMode"))
        XCTAssertTrue(toolbar.contains("var consoleMode: ConsoleMode"))
    }

    func testLiveModeDoesNotMountInactiveSetupTabsDuringModeSwitch() throws {
        let mainContent = try sourceText("Views/AppShell/ActiveConsoleLayer.swift")

        XCTAssertTrue(mainContent.contains("setupContentTabs"))
        XCTAssertTrue(mainContent.contains("liveContent"))
        XCTAssertFalse(mainContent.contains("hasMountedLiveMode"))
        XCTAssertFalse(mainContent.contains("prewarmLiveModeLayer"))
        XCTAssertTrue(mainContent.contains("ConsoleModeMountPolicy.shouldMountSetupLayer("))
        XCTAssertTrue(mainContent.contains("ConsoleModeMountPolicy.shouldMountLiveLayer("))
        XCTAssertFalse(mainContent.contains("consoleModeRetainedLayer(isActive: consoleMode == .setup)"))
        XCTAssertTrue(mainContent.contains("ActiveConsoleLayer(isActive: consoleMode == .live)"))
        XCTAssertFalse(mainContent.contains("retainedTab(.preview) {\n                    if consoleMode == .live"))
        XCTAssertFalse(mainContent.contains("activeContentTab"))
    }

    func testSetupTabsMountLazilyToAvoidLiveSetupSwitchStalls() throws {
        let content = try sourceText("ContentView.swift")
        let mainContent = try sourceText("Views/AppShell/ActiveConsoleLayer.swift")

        XCTAssertTrue(content.contains("@State private var loadedSetupTabs"))
        XCTAssertTrue(mainContent.contains("shouldMountSetupTab(.audioMixer)"))
        XCTAssertTrue(mainContent.contains("shouldMountSetupTab(.overlays)"))
        XCTAssertTrue(content.contains("markSetupTabLoaded"))
        XCTAssertTrue(content.contains("trimLoadedSetupTabsForLiveMode"))
    }

    func testSetupLayerUnmountsWhileLiveModeIsActive() throws {
        let mainContent = try sourceText("Views/AppShell/ActiveConsoleLayer.swift")

        XCTAssertFalse(ConsoleModeMountPolicy.shouldMountSetupLayer(
            consoleMode: .live,
            selectedTab: .preview,
            loadedTabs: [.preview]
        ))
        XCTAssertTrue(mainContent.contains("ConsoleModeMountPolicy.shouldMountSetupLayer("))
        XCTAssertFalse(mainContent.contains("consoleModeRetainedLayer(isActive: consoleMode == .setup)"))
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
        let mainContent = try sourceText("Views/AppShell/ActiveConsoleLayer.swift")
        let policy = try sourceText("Models/ConsoleModeMountPolicy.swift")

        XCTAssertTrue(ConsoleModeMountPolicy.shouldMountLiveLayer(consoleMode: .live))
        XCTAssertFalse(ConsoleModeMountPolicy.shouldMountLiveLayer(consoleMode: .setup))
        XCTAssertFalse(mainContent.contains("hasMountedLiveMode"))
        XCTAssertFalse(policy.contains("hasMountedLiveLayer"))
        XCTAssertFalse(mainContent.contains("prewarmLiveModeLayer"))
    }

    func testConsoleModeSwitchesAvoidWholeLayoutAnimation() throws {
        let content = try sourceText("ContentView.swift")

        XCTAssertFalse(content.contains("withAnimation(.easeInOut(duration: 0.16)) {\n                    viewModel.consoleMode = .live"))
        XCTAssertFalse(content.contains("withAnimation(.easeInOut(duration: 0.16)) {\n                    viewModel.navigateToSetup(viewModel.selectedMainTab)"))
    }

    func testLiveReturnToSetupButtonDoesNotDuplicateBackArrowCopy() throws {
        let modeCluster = try sourceText("Views/AppShell/ConsoleModeCluster.swift")

        XCTAssertTrue(modeCluster.contains("title: \"准备\""))
        XCTAssertTrue(modeCluster.contains("systemImage: \"chevron.left\""))
        XCTAssertFalse(modeCluster.contains("title: \"← 准备\""))
    }

    func testInactiveRetainedConsoleLayerIsHiddenInsteadOfTransparentRendered() throws {
        let layer = try sourceText("Views/AppShell/ActiveConsoleLayer.swift")

        XCTAssertTrue(layer.contains("if isActive {"))
        XCTAssertTrue(layer.contains(".hidden()"))
        XCTAssertFalse(layer.contains(".opacity(isActive ? 1 : 0)"))
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
        let modeCluster = try sourceText("Views/AppShell/ConsoleModeCluster.swift")
        let app = try sourceText("App.swift")

        XCTAssertTrue(modeCluster.contains("tab.setupMenuShortcutLabel"))
        XCTAssertTrue(modeCluster.contains(".keyboardShortcut(KeyEquivalent(Character(tab.setupShortcutKey)), modifiers: .command)"))
        XCTAssertFalse(modeCluster.contains("ellipsis"))

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
