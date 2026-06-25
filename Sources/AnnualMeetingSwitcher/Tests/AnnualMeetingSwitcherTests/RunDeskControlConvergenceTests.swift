import CoreGraphics
import XCTest
@testable import LiveSwitcher

final class RunDeskControlConvergenceTests: XCTestCase {
    func testProgramMonitorUtilitiesAreVisibleWithoutDisclosure() throws {
        let source = try sourceText("Views/ProgramMonitorView.swift")

        XCTAssertFalse(source.contains("DisclosureGroup"))
        XCTAssertFalse(source.contains("utilitiesDisclosure"))
        XCTAssertTrue(source.contains("monitorUtilitiesStack"))
        XCTAssertFalse(source.contains("transitionControlCard"))
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

        XCTAssertTrue(source.contains("没有待机壁纸"))
        XCTAssertTrue(source.contains("导入壁纸"))
        XCTAssertTrue(source.contains("WallpaperImportService.presentPicker"))
        XCTAssertTrue(source.contains(" 张"))
    }

    func testSetupRunDeskRightRailNoLongerOwnsModeControls() throws {
        let source = try sourceText("Views/LiveOpsPanel.swift")

        XCTAssertFalse(source.contains("modesCard"))
        XCTAssertFalse(source.contains("opsCard(title: \"Modes\""))
        XCTAssertFalse(source.contains("audioModesRow"))
        XCTAssertFalse(source.contains("modeToggleRow("))
    }

    func testSetupRunDeskRightRailDoesNotDuplicateSetupAudioDock() throws {
        let source = try sourceText("Views/LiveOpsPanel.swift")

        XCTAssertFalse(source.contains("private var audioCard"))
        XCTAssertFalse(source.contains("private var bgmMiniCard"))
        XCTAssertFalse(source.contains("BGM progress"))
        XCTAssertFalse(source.contains("Open audio mixer page"))
        XCTAssertFalse(source.contains("Switch to Live"))
        XCTAssertTrue(source.contains("进入现场"))
        XCTAssertTrue(source.contains("onSwitchToLive"))
    }

    func testLeftPanelUsesVisibleAddSourceGridAndNonFocusableRefresh() throws {
        let source = try sourceText("Views/LeftPanel.swift")

        XCTAssertFalse(source.contains("Menu {"))
        XCTAssertEqual(source.components(separatedBy: "addSourceButton(title:").count - 1, 4)
        XCTAssertTrue(source.contains(".focusable(false)"))
        XCTAssertFalse(source.contains("EmptyStateView("))
        XCTAssertTrue(source.contains("Text(\"拖入文件，或使用上方按钮添加\")"))
        XCTAssertFalse(source.contains("Text(\"拖入文件\")"))
        XCTAssertFalse(source.contains("Text(\"或使用上方按钮添加\")"))
        XCTAssertTrue(source.contains(".minimumScaleFactor(0.78)"))
        XCTAssertTrue(source.contains("queueFooter"))
    }

    func testProgramMonitorPreviewDeckIsExplicitlyCenteredWithoutChangingCanvas() throws {
        let source = try sourceText("Views/ProgramMonitorView.swift")

        XCTAssertTrue(source.contains("previewDeckFrame"))
        XCTAssertTrue(source.contains(".frame(maxWidth: .infinity, alignment: .center)"))
        XCTAssertTrue(source.contains(".aspectRatio(ProgramMonitorPreviewDeckLayout.aspectRatio, contentMode: .fit)"))
        XCTAssertTrue(source.contains("static let aspectRatio: CGFloat = 16.0 / 9.0"))
        XCTAssertTrue(source.contains("ProgramMonitorOverlayCanvas.logicalSize"))
        XCTAssertTrue(source.contains("ActiveProgramOverlayLayer("))
        XCTAssertFalse(source.contains(".scaledToFill()"))
    }

    func testProgramMonitorPreviewDeckKeepsSixteenNineAtSetupWidths() {
        let setupWidths: [CGFloat] = [800, 1_200, 1_600]

        for containerWidth in setupWidths {
            let layout = ProgramMonitorPreviewDeckLayout.make(
                containerWidth: containerWidth,
                maxHeight: 342
            )

            XCTAssertEqual(layout.size.width / layout.size.height, 16.0 / 9.0, accuracy: 0.001)
            XCTAssertLessThanOrEqual(layout.size.width, containerWidth)
            XCTAssertEqual(layout.leftGutter, layout.rightGutter, accuracy: 0.001)
        }
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

        XCTAssertEqual(state.displayStatusText, "待选")
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
