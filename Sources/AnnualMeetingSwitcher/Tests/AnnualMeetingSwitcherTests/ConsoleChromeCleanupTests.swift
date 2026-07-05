import XCTest

final class ConsoleChromeCleanupTests: XCTestCase {
    func testContentViewDoesNotKeepLowValueBottomStatusBar() throws {
        let source = try sourceText("ContentView.swift")

        XCTAssertFalse(source.contains("StatusBar()"))
        XCTAssertFalse(source.contains("struct StatusBar"))
    }

    func testMainToolbarHasSingleActionPathWithoutLegacyFixedWidths() throws {
        let source = try sourceText("Views/MainToolbar.swift")

        XCTAssertFalse(source.contains("ViewThatFits(in: .horizontal)"))
        XCTAssertFalse(source.contains("compactToolbarButton"))
        XCTAssertFalse(source.contains("compactPreflightButton"))
        XCTAssertFalse(source.contains("frame(width: 112"))
        XCTAssertFalse(source.contains("ToolbarActionModel"))
        XCTAssertFalse(source.contains("panicButton"))
        XCTAssertFalse(source.contains("togglePanic"))
        XCTAssertTrue(source.contains("toolbarModeButtons"))
        XCTAssertFalse(source.contains("Toggle(isOn"))
        XCTAssertTrue(source.contains("preflightButton"))
        XCTAssertTrue(source.contains("helpButton"))
    }

    func testTopChromeShowsNavigationAffordancesForSetupAndPreflight() throws {
        let toolbar = try sourceText("Views/MainToolbar.swift")
        let modeCluster = try sourceText("Views/AppShell/ConsoleModeCluster.swift")

        XCTAssertTrue(toolbar.contains("chevron.down"))
        XCTAssertTrue(modeCluster.contains("title: \"准备\""))
        XCTAssertFalse(modeCluster.contains("title: \"← 准备\""))
        XCTAssertTrue(modeCluster.contains("systemImage: \"chevron.left\""))
        XCTAssertTrue(modeCluster.contains("accessibilityHint(\"返回准备模式\")"))
    }

    func testPanicIsPlacedBeforeConsoleModeClusterAndModesUseOldToolbarSlot() throws {
        let content = try sourceText("ContentView.swift")
        let navigationBar = try sourceText("Views/AppShell/PrimaryNavigationBar.swift")
        let toolbar = try sourceText("Views/MainToolbar.swift")

        guard let panic = navigationBar.range(of: "PanicChromeContainer("),
              let consoleModeCluster = navigationBar.range(of: "ConsoleModeCluster(") else {
            return XCTFail("Expected primary chrome to render panic before the setup/live mode cluster.")
        }
        XCTAssertLessThan(panic.lowerBound, consoleModeCluster.lowerBound)
        XCTAssertTrue(navigationBar.contains("ToolbarLayoutMetrics.panicToModeClusterSpacing"))
        XCTAssertTrue(content.contains("viewModel.togglePanicMode()"))
        XCTAssertTrue(toolbar.contains("toolbarModeButtons"))
        XCTAssertTrue(toolbar.contains("toggleSpeakerMode()"))
        XCTAssertTrue(toolbar.contains("viewModel.togglePPTMode(source: pptModeToggleSource)"))
        XCTAssertFalse(toolbar.contains("viewModel.isPageInterceptEnabled.toggle()"))
        XCTAssertTrue(toolbar.contains("主持人"))
        XCTAssertTrue(toolbar.contains("PPT"))
    }

    func testTopChromeUsesCompactSegmentedControlSurface() throws {
        let navigationBar = try sourceText("Views/AppShell/PrimaryNavigationBar.swift")
        let modeCluster = try sourceText("Views/AppShell/ConsoleModeCluster.swift")
        let components = try sourceText("Views/Theme/StudioTheme+Components.swift")

        XCTAssertTrue(navigationBar.contains("StudioTheme.Surface.raised.opacity(0.92)"))
        XCTAssertTrue(navigationBar.contains("StudioTheme.hairline"))
        XCTAssertFalse(navigationBar.contains("StudioTheme.Surface.base.opacity(0.55)"))
        XCTAssertTrue(modeCluster.contains("RoundedRectangle(cornerRadius: StudioTheme.radiusL"))
        XCTAssertFalse(modeCluster.contains("Capsule(style: .continuous).fill(StudioTheme.Surface.base)"))
        XCTAssertTrue(components.contains("struct NavigationTabButton"))
        XCTAssertTrue(components.contains("RoundedRectangle(cornerRadius: StudioTheme.radiusM"))
    }

    func testGlobalArrowShortcutsRequirePresentationControl() throws {
        let monitor = try sourceText("Views/AppShell/GlobalKeyMonitor.swift")

        XCTAssertTrue(monitor.contains("let presentationShortcutsEnabled = vm.isPageInterceptEnabled || vm.currentProgramItem?.supportsPresentationControl == true"))
        XCTAssertTrue(monitor.contains("guard presentationShortcutsEnabled else { return event }"))
    }

    func testGlobalShortcutsRespectNativeControlFocus() throws {
        let monitor = try sourceText("Views/AppShell/GlobalKeyMonitor.swift")

        XCTAssertTrue(monitor.contains("GlobalShortcutPolicy.shouldPassThroughFocusedResponder(in: event.window, keyCode: event.keyCode)"))
    }

    func testNonEmergencyGlobalShortcutsIgnoreShiftModifiedKeys() throws {
        let monitor = try sourceText("Views/AppShell/GlobalKeyMonitor.swift")

        XCTAssertTrue(monitor.contains("GlobalShortcutPolicy.hasNonEmergencyShortcutModifiers(event.modifierFlags)"))
    }

    func testRunQueueDoesNotInstallDuplicateUnmodifiedNumberShortcuts() throws {
        let leftPanel = try sourceText("Views/Setup/LeftPanel.swift")

        XCTAssertFalse(leftPanel.contains("ShortcutKeyHandler"))
        XCTAssertFalse(leftPanel.contains(".keyboardShortcut(KeyEquivalent(Character(\"\\(index)\")), modifiers: [])"))
    }

    func testStaleToolbarActionModelWasRemoved() throws {
        XCTAssertFalse(sourceExists("Models/ToolbarActionModel.swift"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try LiveSwitcherTests.sourceText(relativePath, filePath: #filePath)
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

    private func sourceExists(_ relativePath: String) -> Bool {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return true
            }
        }
        return false
    }
}
