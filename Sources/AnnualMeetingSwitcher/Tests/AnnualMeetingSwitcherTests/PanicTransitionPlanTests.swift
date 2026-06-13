import XCTest
@testable import LiveSwitcher

final class PanicTransitionPlanTests: XCTestCase {
    func testActivationPlanContainsSnapshot() {
        let snapshot = PanicPlaybackSnapshot(
            currentProgramID: UUID(),
            wasMediaPlaying: true,
            currentBGMID: nil,
            wasBGMPlaying: false
        )

        let plan = PanicActivationPlan(
            snapshot: snapshot,
            shouldPauseMediaImmediately: true,
            shouldPauseBGMAfterFade: false
        )

        XCTAssertEqual(plan.snapshot, snapshot)
    }

    func testActivationPlanSeparatesImmediateMediaPauseFromDelayedBGMPause() {
        let plan = PanicActivationPlan(
            snapshot: PanicPlaybackSnapshot(
                currentProgramID: nil,
                wasMediaPlaying: false,
                currentBGMID: UUID(),
                wasBGMPlaying: true
            ),
            shouldPauseMediaImmediately: false,
            shouldPauseBGMAfterFade: true
        )

        XCTAssertFalse(plan.shouldPauseMediaImmediately)
        XCTAssertTrue(plan.shouldPauseBGMAfterFade)
    }

    func testDeactivationPlanSeparatesMediaAndBGMResume() {
        let plan = PanicDeactivationPlan(
            snapshot: nil,
            shouldResumeMedia: true,
            shouldResumeBGM: false
        )

        XCTAssertTrue(plan.shouldResumeMedia)
        XCTAssertFalse(plan.shouldResumeBGM)
    }
}
