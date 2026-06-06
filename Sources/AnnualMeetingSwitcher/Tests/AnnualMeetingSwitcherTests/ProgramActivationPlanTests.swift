import XCTest
@testable import LiveSwitcher

final class ProgramActivationPlanTests: XCTestCase {
    func testPlanStoresRuntimeSelectionAndSideEffectWithoutRuntimeDependencies() {
        let item = mediaItem()
        let plan = ProgramActivationPlan(
            item: item,
            runtimeSelection: .queued(item.id),
            shouldStopCurrentDeckPresentation: false,
            shouldClearHTML: true,
            sideEffect: .none
        )

        XCTAssertEqual(plan.item, item)
        XCTAssertEqual(plan.runtimeSelection, .queued(item.id))
        XCTAssertEqual(plan.sideEffect, .none)
    }

    func testPlanDoesNotReferenceSwitcherViewModel() throws {
        let source = try planSource()

        XCTAssertFalse(source.contains("SwitcherViewModel"))
    }

    func testPlanDoesNotReferenceLiveRuntimeStore() throws {
        let source = try planSource()

        XCTAssertFalse(source.contains("LiveRuntimeStore"))
    }

    private func planSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/ProgramActivationPlan.swift")
    }

    private func mediaItem() -> ProgramItem {
        ProgramItem(
            title: "Video",
            subtitle: "VIDEO",
            sourceURL: URL(fileURLWithPath: "/tmp/video.mp4")
        )
    }
}
