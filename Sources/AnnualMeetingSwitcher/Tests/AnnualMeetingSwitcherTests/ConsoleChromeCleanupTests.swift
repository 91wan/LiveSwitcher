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
        let content = try sourceText("ContentView.swift")

        XCTAssertTrue(toolbar.contains("chevron.down"))
        XCTAssertTrue(content.contains("title: \"准备\""))
        XCTAssertFalse(content.contains("title: \"← 准备\""))
        XCTAssertTrue(content.contains("systemImage: \"chevron.left\""))
        XCTAssertTrue(content.contains("accessibilityHint(\"返回准备模式\")"))
    }

    func testPanicIsPlacedBeforeConsoleModeClusterAndModesUseOldToolbarSlot() throws {
        let content = try sourceText("ContentView.swift")
        let toolbar = try sourceText("Views/MainToolbar.swift")

        guard let panic = content.range(of: "panicChromeButton"),
              let consoleModeCluster = content.range(of: "consoleModeCluster") else {
            return XCTFail("Expected ContentView chrome to render panic before the setup/live mode cluster.")
        }
        XCTAssertLessThan(panic.lowerBound, consoleModeCluster.lowerBound)
        XCTAssertTrue(content.contains("ToolbarLayoutMetrics.panicToModeClusterSpacing"))
        XCTAssertTrue(content.contains("viewModel.togglePanicMode()"))
        XCTAssertTrue(toolbar.contains("toolbarModeButtons"))
        XCTAssertTrue(toolbar.contains("toggleSpeakerMode()"))
        XCTAssertTrue(toolbar.contains("viewModel.togglePPTMode(source: pptModeToggleSource)"))
        XCTAssertFalse(toolbar.contains("viewModel.isPageInterceptEnabled.toggle()"))
        XCTAssertTrue(toolbar.contains("主持人"))
        XCTAssertTrue(toolbar.contains("PPT"))
    }

    func testGlobalArrowShortcutsRequirePresentationControl() throws {
        let content = try sourceText("ContentView.swift")

        XCTAssertTrue(content.contains("let presentationShortcutsEnabled = vm.isPageInterceptEnabled || vm.currentProgramItem?.supportsPresentationControl == true"))
        XCTAssertTrue(content.contains("guard presentationShortcutsEnabled else { return event }"))
    }

    func testGlobalShortcutsRespectNativeControlFocus() throws {
        let content = try sourceText("ContentView.swift")

        XCTAssertTrue(content.contains("GlobalShortcutPolicy.shouldPassThroughFocusedResponder(in: event.window, keyCode: event.keyCode)"))
    }

    func testNonEmergencyGlobalShortcutsIgnoreShiftModifiedKeys() throws {
        let content = try sourceText("ContentView.swift")

        XCTAssertTrue(content.contains("GlobalShortcutPolicy.hasNonEmergencyShortcutModifiers(event.modifierFlags)"))
    }

    func testRunQueueDoesNotInstallDuplicateUnmodifiedNumberShortcuts() throws {
        let leftPanel = try sourceText("Views/LeftPanel.swift")

        XCTAssertFalse(leftPanel.contains("ShortcutKeyHandler"))
        XCTAssertFalse(leftPanel.contains(".keyboardShortcut(KeyEquivalent(Character(\"\\(index)\")), modifiers: [])"))
    }

    func testStaleToolbarActionModelWasRemoved() throws {
        XCTAssertFalse(sourceExists("Models/ToolbarActionModel.swift"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
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
