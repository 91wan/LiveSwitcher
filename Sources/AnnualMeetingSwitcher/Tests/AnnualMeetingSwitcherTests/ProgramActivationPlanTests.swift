import XCTest
@testable import LiveSwitcher

final class ProgramActivationPlanTests: XCTestCase {
    func testPlanStoresRuntimeSelectionAndPhaseEffectsWithoutRuntimeDependencies() {
        let item = mediaItem()
        let plan = ProgramActivationPlan(
            item: item,
            runtimeSelection: .queued(item.id),
            preSelectionEffects: [],
            postSelectionEffects: [.clearHTML, .resetMutedMediaStartupFlag]
        )

        XCTAssertEqual(plan.item, item)
        XCTAssertEqual(plan.runtimeSelection, .queued(item.id))
        XCTAssertEqual(plan.preSelectionEffects, [])
        XCTAssertEqual(plan.postSelectionEffects, [.clearHTML, .resetMutedMediaStartupFlag])
    }

    func testPlanDoesNotReferenceSwitcherViewModel() throws {
        let source = try planSource()

        XCTAssertFalse(source.contains("SwitcherViewModel"))
    }

    func testPlanDoesNotReferenceLiveRuntimeStore() throws {
        let source = try planSource()

        XCTAssertFalse(source.contains("LiveRuntimeStore"))
    }

    func testPlanUsesExplicitPhaseTerminology() throws {
        let source = try planSource()

        XCTAssertTrue(source.contains("PreSelectionEffect"))
        XCTAssertTrue(source.contains("PostSelectionEffect"))
        XCTAssertTrue(source.contains("preSelectionEffects"))
        XCTAssertTrue(source.contains("postSelectionEffects"))
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
