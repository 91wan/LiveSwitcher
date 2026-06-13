import XCTest
@testable import LiveSwitcher

@MainActor
final class PanicRuntimeEffectExecutionTests: XCTestCase {
    func testSchedulePanicBGMPauseEffectCallsPanicDelayPort() {
        let port = ClosurePanicDelayPort()
        let snapshot = panicSnapshot()
        var received: (Int, PanicPlaybackSnapshot, TimeInterval)?
        port.scheduleBGMPauseHandler = { generation, snapshot, delay, _ in
            received = (generation, snapshot, delay)
        }
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, panicDelay: port)

        runner.run(
            [.schedulePanicBGMPause(generation: 4, snapshot: snapshot, delay: 0.5)],
            currentState: { LiveRuntimeState() },
            dispatch: { _ in }
        )

        XCTAssertEqual(received?.0, 4)
        XCTAssertEqual(received?.1, snapshot)
        XCTAssertEqual(received?.2, 0.5)
    }

    func testCancelPanicBGMPauseEffectCallsPanicDelayPort() {
        let port = ClosurePanicDelayPort()
        var received: Int?
        port.cancelBGMPauseHandler = { generation in
            received = generation
        }
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, panicDelay: port)

        runner.run(
            [.cancelPanicBGMPause(generation: 4)],
            currentState: { LiveRuntimeState() },
            dispatch: { _ in }
        )

        XCTAssertEqual(received, 4)
    }

    func testPanicDelayPortCanDispatchDelayElapsedThroughContext() {
        let port = ClosurePanicDelayPort()
        let snapshot = panicSnapshot()
        var dispatched: [LiveRuntimeAction] = []
        port.scheduleBGMPauseHandler = { generation, snapshot, _, context in
            context.dispatch(.panicBGMPauseDelayElapsed(generation: generation, snapshot: snapshot))
        }
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, panicDelay: port)

        runner.run(
            [.schedulePanicBGMPause(generation: 4, snapshot: snapshot, delay: 0.5)],
            currentState: { LiveRuntimeState() },
            dispatch: { dispatched.append($0) }
        )

        XCTAssertEqual(dispatched, [.panicBGMPauseDelayElapsed(generation: 4, snapshot: snapshot)])
    }

    func testPanicDelayEffectsAreRecordedWithoutPrivatePaths() {
        let snapshot = panicSnapshot()
        let runner = LiveRuntimeEffectRunner.recording()

        runner.run(
            [
                .schedulePanicBGMPause(generation: 4, snapshot: snapshot, delay: 0.5),
                .cancelPanicBGMPause(generation: 4)
            ],
            currentState: { LiveRuntimeState() },
            dispatch: { _ in }
        )

        let rendered = String(describing: runner.recordedEffects)
        XCTAssertTrue(runner.recordedEffects.contains(.schedulePanicBGMPause(generation: 4, snapshot: snapshot, delay: 0.5)))
        XCTAssertTrue(runner.recordedEffects.contains(.cancelPanicBGMPause(generation: 4)))
        XCTAssertFalse(rendered.contains("/tmp"))
        XCTAssertFalse(rendered.contains("Walk In"))
    }

    private func panicSnapshot() -> PanicPlaybackSnapshot {
        PanicPlaybackSnapshot(
            currentProgramID: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            wasMediaPlaying: true,
            currentBGMID: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
            wasBGMPlaying: true
        )
    }
}
