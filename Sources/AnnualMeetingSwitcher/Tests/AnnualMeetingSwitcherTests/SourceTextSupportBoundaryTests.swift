import XCTest

final class SourceTextSupportBoundaryTests: XCTestCase {
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
