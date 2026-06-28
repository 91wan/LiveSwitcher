import CoreGraphics
import XCTest
@testable import LiveSwitcher

final class LiveModeLayoutTests: XCTestCase {
    func testLiveModeLayoutMetricsProtectMonitorPriorityAndHitTargets() {
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.monitorHeightRatio, 0.50)
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.audioStripHeight, 110)
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.sourceRailWidth, 200)
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.sourceRailWidthEmpty, 80)
        XCTAssertLessThanOrEqual(LiveModeLayoutMetrics.sourceRailWidthEmpty, 120)
        XCTAssertLessThan(LiveModeLayoutMetrics.sourceRailWidthEmpty, LiveModeLayoutMetrics.sourceRailWidth)
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.quickRailWidth, 200)
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.footerHeight, 26)
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.transportButtonSize, 32)
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.quickActionButtonHeight, 34)
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.contentTopPadding, 14)
        XCTAssertGreaterThanOrEqual(LiveModeLayoutMetrics.contentBottomPadding, 6)
        XCTAssertGreaterThanOrEqual(ConsoleChromeLayoutMetrics.navigationBarMinHeight, 76)
    }

    func testLiveModeViewFilesStayFocusedAfterPostStableSplit() throws {
        let expectedFiles = [
            "LiveModeView.swift",
            "LiveSourceRail.swift",
            "LiveProgramStack.swift",
            "LiveAudioStrip.swift",
            "LiveQuickRail.swift",
            "LiveQuickRail+BGM.swift",
            "LiveQuickRail+Overlays.swift",
            "LiveRuntimeStatusBar.swift",
            "LiveWallpaperPickerThumb.swift"
        ]
        let viewsDirectory = try sourceURL("Views/LiveModeView.swift").deletingLastPathComponent()

        for fileName in expectedFiles {
            let fileURL = viewsDirectory.appendingPathComponent(fileName)
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "\(fileName) should exist")

            let source = try String(contentsOf: fileURL, encoding: .utf8)
            let lineCount = source.split(separator: "\n", omittingEmptySubsequences: false).count
            let maxLineCount = fileName == "LiveModeView.swift" ? 350 : 450
            XCTAssertLessThanOrEqual(lineCount, maxLineCount, "\(fileName) should stay focused")
        }
    }

    func testLiveModeColumnMetricsKeepCurrentProgramDominant() {
        let sideRails = LiveModeLayoutMetrics.sourceRailWidth
            + LiveModeLayoutMetrics.quickRailWidth
            + LiveModeLayoutMetrics.mainColumnSpacing * 2
            + LiveModeLayoutMetrics.horizontalContentPadding * 2

        XCTAssertGreaterThan(LiveModeLayoutMetrics.minimumProgramColumnWidth, sideRails)
        XCTAssertLessThan(LiveModeLayoutMetrics.sourceRailWidthEmpty, LiveModeLayoutMetrics.sourceRailWidth * 0.5)
        XCTAssertEqual(LiveModeLayoutMetrics.railThumbnailSize.width / LiveModeLayoutMetrics.railThumbnailSize.height, 1.76, accuracy: 0.01)
    }

    func testLiveModeSimplicityPolicyAllowsOnlyOperatorActionsInLiveMode() {
        XCTAssertLessThanOrEqual(
            LiveModeSimplicityPolicy.primaryActions.count,
            LiveModeSimplicityPolicy.maxPrimaryActionCount
        )
        XCTAssertTrue(LiveModeSimplicityPolicy.primaryActions.allSatisfy(LiveModeSimplicityPolicy.isAllowed))
        XCTAssertTrue(LiveModeConfigurationSurface.allCases.allSatisfy(LiveModeSimplicityPolicy.isForbidden))
        XCTAssertFalse(LiveModeSimplicityPolicy.primaryActions.map(\.rawValue).contains("editProgramQueue"))
    }

    func testProgramMonitorPreviewDeckKeepsSixteenNineAcrossSetupAndLiveWidths() {
        let setupWidths: [CGFloat] = [800, 1_200, 1_600]

        for containerWidth in setupWidths {
            let layout = ProgramMonitorPreviewDeckLayout.make(
                containerWidth: containerWidth,
                maxHeight: 342
            )

            XCTAssertEqual(layout.size.width / layout.size.height, ProgramMonitorPreviewDeckLayout.aspectRatio, accuracy: 0.001)
            XCTAssertLessThanOrEqual(layout.size.width, containerWidth)
            XCTAssertEqual(layout.leftGutter, layout.rightGutter, accuracy: 0.001)
        }

        let liveLayout = ProgramMonitorPreviewDeckLayout.make(containerWidth: 1_600, maxHeight: .infinity)
        XCTAssertEqual(liveLayout.size.width, 1_600, accuracy: 0.001)
        XCTAssertEqual(liveLayout.leftGutter, 0, accuracy: 0.001)
    }

    func testProgramMonitorOverlayCanvasMatchesOutputAspectRatio() {
        XCTAssertEqual(
            ProgramMonitorOverlayCanvas.logicalSize.width / ProgramMonitorOverlayCanvas.logicalSize.height,
            ProgramMonitorPreviewDeckLayout.aspectRatio,
            accuracy: 0.001
        )
        XCTAssertEqual(ProgramMonitorOverlayCanvas.logicalSize, CGSize(width: 1920, height: 1080))
    }

    func testProgramMonitorChromeLayoutRespondsToAvailableWidth() {
        XCTAssertEqual(ProgramMonitorChromeLayoutModel.make(width: 620).variant, .full)
        XCTAssertEqual(ProgramMonitorChromeLayoutModel.make(width: 420).variant, .compact)
        XCTAssertEqual(ProgramMonitorChromeLayoutModel.make(width: 240).variant, .stateOnly)
        XCTAssertTrue(ProgramMonitorChromeLayoutModel.make(width: 620).showsFullInlineStatus)
        XCTAssertTrue(ProgramMonitorChromeLayoutModel.make(width: 420).showsCompactInlineStatus)
    }

    func testProgramMonitorInfoBlocksDescribeCurrentAndNextStates() {
        let current = ProgramMonitorInfoBlockModel.current(
            item: programItem("Opening", subtitle: "video"),
            isBroadcasting: true,
            isPlaying: true,
            isHTMLLoaded: false
        )
        let next = ProgramMonitorInfoBlockModel.next(item: programItem("Awards", subtitle: "pptx"))

        XCTAssertEqual(current.title, "当前")
        XCTAssertEqual(current.value, "Opening")
        XCTAssertEqual(current.subtitle, "媒体播放中")
        XCTAssertEqual(current.badgeText, "直播")
        XCTAssertEqual(current.status, .live)
        XCTAssertEqual(next.title, "下一项")
        XCTAssertEqual(next.value, "Awards")
        XCTAssertEqual(next.subtitle, "PPTX")
        XCTAssertEqual(next.status, .ready)
    }

    func testSourceRailRowLabelsExposeQueueRoleSemantics() {
        let current = SourceRailRowLabelModel.make(queuePosition: 1, queueRole: .current, sourceLabel: "VIDEO")
        let next = SourceRailRowLabelModel.make(queuePosition: 2, queueRole: .next, sourceLabel: "PPTX")
        let queued = SourceRailRowLabelModel.make(queuePosition: 3, queueRole: .queued, sourceLabel: "HTML")

        XCTAssertEqual(current.text, "1 · 正在播 · VIDEO")
        XCTAssertEqual(current.accessibilityLabel, "第 1 项，正在播，VIDEO")
        XCTAssertEqual(next.text, "2 · 下一项 · PPTX")
        XCTAssertEqual(queued.text, "3 · HTML")
    }

    func testLiveRuntimeStatusBarMarksProjectionProgramAndAudioRisk() {
        let normal = LiveStatusBarModel.make(
            snapshot: snapshot(isBroadcasting: false, speaker: false, panic: false),
            nextProgramTitle: "Awards"
        )
        let speaker = LiveStatusBarModel.make(
            snapshot: snapshot(isBroadcasting: true, speaker: true, panic: false),
            nextProgramTitle: nil
        )
        let panic = LiveStatusBarModel.make(
            snapshot: snapshot(isBroadcasting: true, speaker: false, panic: true),
            nextProgramTitle: nil
        )

        XCTAssertEqual(normal.projection.value, "待机")
        XCTAssertEqual(normal.current.value, "Opening · VIDEO")
        XCTAssertEqual(normal.next.value, "Awards")
        XCTAssertEqual(normal.audio.value, "正常")
        XCTAssertEqual(speaker.audio.value, "主持人")
        XCTAssertEqual(speaker.audio.status, .warn)
        XCTAssertEqual(panic.audio.value, "紧急切黑静音")
        XCTAssertEqual(panic.audio.status, .fail)
        XCTAssertTrue(panic.isCritical)
    }

    private func programItem(_ title: String, subtitle: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: subtitle, sourceURL: URL(fileURLWithPath: "/tmp/\(title).mov"))
    }

    private func snapshot(
        isBroadcasting: Bool,
        speaker: Bool,
        panic: Bool
    ) -> LivePreflightSnapshot {
        LivePreflightSnapshot(
            appVersion: "0.5.0",
            hasExternalDisplay: true,
            isBroadcasting: isBroadcasting,
            broadcastSafetyNotice: nil,
            programItemCount: 1,
            currentProgramTitle: "Opening",
            currentProgramSource: "VIDEO",
            bgmItemCount: 1,
            isBGMPlaying: false,
            isBGMAudioTakeoverActive: false,
            isSpeakerMode: speaker,
            isPanicMode: panic,
            isPageInterceptEnabled: false,
            activeOverlayCount: 0,
            wallpaperCount: 1,
            autoPlayNextVideoOnEnd: false,
            effectiveMediaVolume: 0.8,
            effectiveBGMVolume: 0.4
        )
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
