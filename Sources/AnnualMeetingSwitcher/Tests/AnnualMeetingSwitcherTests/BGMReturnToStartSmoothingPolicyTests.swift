import XCTest
@testable import LiveSwitcher

final class BGMReturnToStartSmoothingPolicyTests: XCTestCase {
    func testPlayingBGMWithAudibleOutputUsesMicroFadePlan() {
        let plan = BGMReturnToStartSmoothingPolicy.plan(
            phase: .playing,
            effectiveBGM: 0.35,
            isMuted: false,
            panicActive: false
        )

        XCTAssertEqual(plan, .smoothed(fadeOut: 0.1, fadeIn: 0.15))
    }

    func testPlayingMutedOrSilentBGMSeeksImmediately() {
        XCTAssertEqual(
            BGMReturnToStartSmoothingPolicy.plan(
                phase: .playing,
                effectiveBGM: 0.35,
                isMuted: true,
                panicActive: false
            ),
            .immediate
        )
        XCTAssertEqual(
            BGMReturnToStartSmoothingPolicy.plan(
                phase: .playing,
                effectiveBGM: 0,
                isMuted: false,
                panicActive: false
            ),
            .immediate
        )
    }

    func testPausedAndSelectedBGMSeekImmediatelyWithoutFade() {
        XCTAssertEqual(
            BGMReturnToStartSmoothingPolicy.plan(
                phase: .paused,
                effectiveBGM: 0.35,
                isMuted: false,
                panicActive: false
            ),
            .immediate
        )
        XCTAssertEqual(
            BGMReturnToStartSmoothingPolicy.plan(
                phase: .selected,
                effectiveBGM: 0.35,
                isMuted: false,
                panicActive: false
            ),
            .immediate
        )
    }

    func testIdleBGMDoesNotEmitASeekPlan() {
        XCTAssertEqual(
            BGMReturnToStartSmoothingPolicy.plan(
                phase: .idle,
                effectiveBGM: 0.35,
                isMuted: false,
                panicActive: false
            ),
            .noOp
        )
    }

    func testPanicActiveNeverFadesBackIn() {
        XCTAssertEqual(
            BGMReturnToStartSmoothingPolicy.plan(
                phase: .playing,
                effectiveBGM: 0.35,
                isMuted: false,
                panicActive: true
            ),
            .immediate
        )
    }
}
