import XCTest

final class SourceTextSupportBoundaryTests: XCTestCase {
    func testLegacySplitSurfacePathsReadConcreteFilesOnly() throws {
        XCTAssertThrowsError(try sourceText("Views/LeftPanel.swift"))
        XCTAssertThrowsError(try sourceText("Views/PreflightPopoverView.swift"))
        XCTAssertThrowsError(try sourceText("Views/SafetyCockpitView.swift"))

        let leftPanel = try sourceText("Views/Setup/LeftPanel.swift")
        let preflight = try sourceText("Views/Support/PreflightPopoverView.swift")
        let safetyCockpit = try sourceText("Views/Support/SafetyCockpitView.swift")

        XCTAssertTrue(leftPanel.contains("struct LeftPanel"))
        XCTAssertFalse(leftPanel.contains("struct ProgramQueueList"))
        XCTAssertFalse(leftPanel.contains("struct ProgramImportDropZone"))

        XCTAssertTrue(preflight.contains("struct PreflightPopoverView"))
        XCTAssertFalse(preflight.contains("struct PreflightSummaryHeader"))
        XCTAssertFalse(preflight.contains("struct PreflightSupportActions"))

        XCTAssertTrue(safetyCockpit.contains("struct SafetyCockpitView"))
        XCTAssertFalse(safetyCockpit.contains("struct SafetyCockpitStatusGrid"))
        XCTAssertFalse(safetyCockpit.contains("struct SafetyCockpitSupportActions"))
    }

    func testExplicitSplitSurfaceHelperReadsFiniteAggregates() throws {
        let setupRail = try sourceTextForSplitSurface(.setupProgramRail)
        let preflight = try sourceTextForSplitSurface(.preflightPopover)
        let safetyCockpit = try sourceTextForSplitSurface(.safetyCockpit)

        XCTAssertTrue(setupRail.contains("struct LeftPanel"))
        XCTAssertTrue(setupRail.contains("struct ProgramQueueList"))
        XCTAssertTrue(preflight.contains("struct PreflightPopoverView"))
        XCTAssertTrue(preflight.contains("struct PreflightSummaryHeader"))
        XCTAssertTrue(safetyCockpit.contains("struct SafetyCockpitView"))
        XCTAssertTrue(safetyCockpit.contains("struct SafetyCockpitStatusGrid"))
    }

    func testSplitSurfaceSourceTextSupportOwnsFiniteSurfaceAggregation() throws {
        let support = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/SplitSurfaceSourceTextSupport.swift"
        )
        let genericSupport = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests/TestSourceTextSupport.swift"
        )

        XCTAssertTrue(support.contains("enum SplitSurface"))
        XCTAssertTrue(support.contains("case setupProgramRail"))
        XCTAssertTrue(support.contains("case preflightPopover"))
        XCTAssertTrue(support.contains("case safetyCockpit"))
        XCTAssertTrue(support.contains("case bgmPlaylist"))
        XCTAssertTrue(support.contains("case overlayControl"))
        XCTAssertTrue(support.contains("func sourceTextForSplitSurface(_ surface: SplitSurface) throws -> String"))

        XCTAssertFalse(genericSupport.contains("func programSetupRailSurfaceText"))
        XCTAssertFalse(genericSupport.contains("func preflightPopoverSurfaceText"))
        XCTAssertFalse(genericSupport.contains("func safetyCockpitSurfaceText"))
        XCTAssertFalse(genericSupport.contains("func bgmPlaylistSurfaceText"))
        XCTAssertFalse(genericSupport.contains("func overlayControlSurfaceText"))
        XCTAssertFalse(genericSupport.contains("isLegacyLeftPanelPath"))
        XCTAssertFalse(genericSupport.contains("isLegacyPreflightPopoverPath"))
        XCTAssertFalse(genericSupport.contains("isLegacySafetyCockpitPath"))
    }

    func testSplitSurfaceAggregationIsLimitedToBoundarySplitAndStaticTests() throws {
        let testsRoot = try repositoryRoot(filePath: #filePath)
            .appendingPathComponent("Sources/AnnualMeetingSwitcher/Tests/AnnualMeetingSwitcherTests")
        let allowedSuffixes = [
            "BoundaryTests.swift",
            "SplitTests.swift",
            "StaticTests.swift"
        ]
        let files = try XCTUnwrap(FileManager.default.enumerator(at: testsRoot, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .filter { $0.lastPathComponent != "SplitSurfaceSourceTextSupport.swift" }

        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            guard text.contains("sourceTextForSplitSurface(") else { continue }

            XCTAssertTrue(
                allowedSuffixes.contains { file.lastPathComponent.hasSuffix($0) },
                "\(file.lastPathComponent) must not use split surface aggregation."
            )
        }
    }

    func testSourceTextReadsConcreteSplitFilesWithoutLegacyAggregation() throws {
        let liveMode = try sourceText("Views/LiveModeView.swift")
        let monitor = try sourceText("Views/ProgramMonitor/ProgramMonitorView.swift")
        let signalSourceRow = try sourceText("Views/ProgramQueue/SignalSourceRow.swift")

        XCTAssertTrue(liveMode.contains("struct LiveModeView"))
        XCTAssertFalse(liveMode.contains("struct LiveSourceRail"))
        XCTAssertFalse(liveMode.contains("struct LiveQuickRail"))

        XCTAssertTrue(monitor.contains("struct ProgramMonitorView"))
        XCTAssertFalse(monitor.contains("struct ProgramMonitorChrome"))
        XCTAssertFalse(monitor.contains("struct ProgramMonitorMediaLayer"))

        XCTAssertTrue(signalSourceRow.contains("struct SignalSourceRow"))
        XCTAssertFalse(signalSourceRow.contains("struct ProgramQueueDragHandle"))
        XCTAssertFalse(signalSourceRow.contains("struct ProgressSliderRow"))
    }

    func testRepositorySourceReadsConcreteFilesWithoutLegacyAggregation() throws {
        let liveMode = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LiveModeView.swift"
        )
        let monitor = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/ProgramMonitor/ProgramMonitorView.swift"
        )
        let runQueue = try optionalRepositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/RunQueueView.swift"
        )

        XCTAssertTrue(liveMode.contains("struct LiveModeView"))
        XCTAssertFalse(liveMode.contains("struct LiveSourceRail"))
        XCTAssertTrue(monitor.contains("struct ProgramMonitorView"))
        XCTAssertFalse(monitor.contains("struct ProgramMonitorChrome"))
        XCTAssertNil(runQueue)
    }
}
