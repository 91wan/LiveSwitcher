import XCTest
@testable import LiveSwitcher

final class RunDeskControlConvergenceTests: XCTestCase {
    func testProgramMonitorUtilitiesAreVisibleWithoutDisclosure() throws {
        let source = try sourceText("Views/ProgramMonitorView.swift")

        XCTAssertFalse(source.contains("DisclosureGroup"))
        XCTAssertFalse(source.contains("utilitiesDisclosure"))
        XCTAssertTrue(source.contains("monitorUtilitiesStack"))
        XCTAssertTrue(source.contains("transitionControlCard"))
        XCTAssertTrue(source.contains("wallpaperTrayCard"))
    }

    func testProgramMonitorChromeDoesNotRepeatStandbyStatus() throws {
        let source = try sourceText("Views/ProgramMonitorView.swift")

        XCTAssertFalse(source.contains("StatusBadge(monitorStateLabel"))
        XCTAssertFalse(source.contains("monitorDisplayMode"))
        XCTAssertFalse(source.contains("previewDeck\n\n            monitorInlineStatusRow"))
        XCTAssertTrue(source.contains(".overlay(alignment: .top)"))
        XCTAssertTrue(source.contains("StudioTheme.monitorText"))
    }

    func testWallpaperEmptyStateKeepsInlineImportAction() throws {
        let source = try sourceText("Views/ProgramMonitorView.swift")

        XCTAssertTrue(source.contains("No standby wallpaper"))
        XCTAssertTrue(source.contains("Import wallpaper"))
        XCTAssertTrue(source.contains("WallpaperImportService.presentPicker"))
        XCTAssertTrue(source.contains(" 张"))
    }

    func testLiveOpsMergesModesIntoAudioCard() throws {
        let source = try sourceText("Views/LiveOpsPanel.swift")

        XCTAssertFalse(source.contains("modesCard"))
        XCTAssertFalse(source.contains("opsCard(title: \"Modes\""))
        XCTAssertTrue(source.contains("audioModesRow"))
        XCTAssertTrue(source.contains("modeToggleRow("))
    }

    func testLeftPanelUsesVisibleAddSourceGridAndNonFocusableRefresh() throws {
        let source = try sourceText("Views/LeftPanel.swift")

        XCTAssertFalse(source.contains("Menu {"))
        XCTAssertEqual(source.components(separatedBy: "addSourceButton(title:").count - 1, 4)
        XCTAssertTrue(source.contains(".focusable(false)"))
        XCTAssertFalse(source.contains("EmptyStateView("))
        XCTAssertTrue(source.contains("Or use one of the buttons above"))
        XCTAssertTrue(source.contains("queueFooter"))
    }

    func testRunDeskRailsHaveLowEmphasisFooters() throws {
        let leftPanel = try sourceText("Views/LeftPanel.swift")
        let liveOps = try sourceText("Views/LiveOpsPanel.swift")

        XCTAssertTrue(leftPanel.contains("queueFooter"))
        XCTAssertTrue(liveOps.contains("runtimeFooter"))
        XCTAssertTrue(liveOps.contains("HostSystemSummary.shortVersionString"))
        XCTAssertFalse(liveOps.contains("ProcessInfo.processInfo.operatingSystemVersionString"))
    }

    func testAutoNextIdleStateIsNeutralAndActiveStateWarns() {
        let idle = AutoNextVideoControlModel.make(isEnabled: false, hasCurrentProgram: false)
        let armedWithoutProgram = AutoNextVideoControlModel.make(isEnabled: true, hasCurrentProgram: false)
        let active = AutoNextVideoControlModel.make(isEnabled: true, hasCurrentProgram: true)

        XCTAssertEqual(idle.statusKind, .idle)
        XCTAssertEqual(idle.systemImage, "play.rectangle.on.rectangle")
        XCTAssertEqual(armedWithoutProgram.statusKind, .idle)
        XCTAssertEqual(active.statusKind, .warn)
        XCTAssertEqual(active.systemImage, "exclamationmark.triangle.fill")
    }

    func testBGMIdleStatusDoesNotLookLikeASelectableBadge() {
        let track = BGMItem(title: "Opening", url: URL(fileURLWithPath: "/tmp/opening.mp3"), category: .warmUp)
        let state = BGMControlsState.make(items: [track], currentItem: nil)

        XCTAssertEqual(state.displayStatusText, "IDLE")
        XCTAssertEqual(state.displayStatusKind, .idle)
    }

    func testDirectorRailsUseNarrowerRunDeskWidth() {
        XCTAssertEqual(StudioTheme.directorRailWidth, 320)
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
}
