import XCTest

final class PostStableMonitorQueueSplitTests: XCTestCase {
    func testProgramMonitorAndRunQueueFilesStayFocusedAfterPostStableSplit() throws {
        let expectedFiles: [String: Int] = [
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitor/ProgramMonitorView.swift": 350,
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitor/ProgramMonitorPreviewDeck.swift": 450,
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitor/ProgramMonitorChrome.swift": 450,
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitor/ProgramMonitorBlackoutOverlay.swift": 450,
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitor/ProgramMonitorMediaLayer.swift": 450,
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitor/ProgramMonitorWallpaperTray.swift": 450,
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramQueue/SignalSourceRow.swift": 249,
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramQueue/SignalSourceRowHeader.swift": 249,
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramQueue/SignalSourceRowStatusChips.swift": 249,
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramQueue/SignalSourceRowControlRail.swift": 249,
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramQueue/SignalSourceRowDropIndicator.swift": 249,
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramQueue/SignalSourceRowStyleModel.swift": 249,
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramQueue/ProgramQueueDragHandle.swift": 450,
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramQueue/ProgramQueueNumberBadge.swift": 450,
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramQueue/ProgramQueueScheduleEditor.swift": 450,
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramQueue/AgendaMarkerEditorPopover.swift": 450,
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramQueue/ProgressSliderRow.swift": 450
        ]
        let root = try LiveSwitcherTests.repositoryRoot(filePath: #filePath)

        for (relativePath, maxLineCount) in expectedFiles {
            let url = root.appendingPathComponent(relativePath)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "\(relativePath) should exist")

            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let source = try String(contentsOf: url, encoding: .utf8)
            let lineCount = source.split(separator: "\n", omittingEmptySubsequences: false).count
            XCTAssertLessThanOrEqual(lineCount, maxLineCount, "\(relativePath) should stay focused")
        }
    }

    func testLegacyMonitorAndQueueEntrypointFilesNoLongerOwnMovedSubviews() throws {
        let root = try LiveSwitcherTests.repositoryRoot(filePath: #filePath)
        let monitorSource = try String(
            contentsOf: root.appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitor/ProgramMonitorView.swift"),
            encoding: .utf8
        )
        let queueSource = try String(
            contentsOf: root.appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramQueue/SignalSourceRow.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(monitorSource.contains("blackoutStatusOverlay"))
        XCTAssertFalse(monitorSource.contains("monitorTopChrome"))
        XCTAssertFalse(monitorSource.contains("wallpaperTray"))
        XCTAssertFalse(queueSource.contains("struct ProgramQueueDragHandle"))
        XCTAssertFalse(queueSource.contains("struct AgendaMarkerEditorPopover"))
        XCTAssertFalse(queueSource.contains("struct ProgressSliderRow"))
        XCTAssertFalse(queueSource.contains("private var selectedControlRail"))
        XCTAssertFalse(queueSource.contains("private var dropIndicatorOverlay"))
        XCTAssertFalse(queueSource.contains("private var sourceTypeChip"))
        XCTAssertFalse(queueSource.contains("private var backgroundFill"))
    }
}
