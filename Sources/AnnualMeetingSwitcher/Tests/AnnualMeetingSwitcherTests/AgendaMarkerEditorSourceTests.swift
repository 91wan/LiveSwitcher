import XCTest
@testable import LiveSwitcher

final class AgendaMarkerEditorSourceTests: XCTestCase {
    func testSetupPanelAddsMarkersThroughEditorPopoverInsteadOfSilentDefault() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LeftPanel.swift")

        XCTAssertTrue(source.contains("Label(\"添加标记\""))
        XCTAssertTrue(source.contains("AgendaMarkerEditorPopover"))
        XCTAssertTrue(source.contains("viewModel.addAgendaMarker(input)"))
        XCTAssertFalse(source.contains("viewModel.addAgendaMarker()"))
        XCTAssertFalse(source.contains("Label(\"标记\""))
    }

    func testRunQueueAndTimelineExposeMarkerEditorForExistingMarkers() throws {
        let runQueue = [
            try sourceText("Views/ProgramQueue/SignalSourceRow.swift"),
            try sourceText("Views/ProgramQueue/SignalSourceRowHeader.swift")
        ].joined(separator: "\n")
        let markerEditor = try sourceText("Views/ProgramQueue/AgendaMarkerEditorPopover.swift")
        let timeline = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/AgendaTimelineView.swift")

        XCTAssertTrue(markerEditor.contains("struct AgendaMarkerEditorPopover"))
        XCTAssertTrue(runQueue.contains("onUpdateAgendaMarker"))
        XCTAssertTrue(runQueue.contains("编辑标记"))
        XCTAssertTrue(runQueue.contains("guard !item.isAgendaMarker else { return }"))
        XCTAssertTrue(timeline.contains("onUpdateAgendaMarker"))
        XCTAssertTrue(timeline.contains("编辑标记"))
        XCTAssertTrue(timeline.contains("AgendaMarkerEditorPopover"))
    }

    func testLiveRailRendersAgendaMarkersAsNonSwitchingCueRows() throws {
        let source = try sourceText("Views/LiveSourceRail.swift")

        XCTAssertTrue(source.contains("LiveSourceRailMarkerCueRow"))
        XCTAssertTrue(source.contains("if item.isAgendaMarker"))
        XCTAssertFalse(source.contains("action: { viewModel.switchToProgramAfterReadinessConfirmation(item) }\n                            )\n                        }"))
    }

    func testMarkerDisplaySourceLabelUsesLocalizedCopy() {
        XCTAssertEqual(ProgramItem.agendaMarker(title: "茶歇").displaySourceLabel, "标记")
    }
}
