import XCTest
@testable import LiveSwitcher

@MainActor
final class PanicRuntimeDelayedBGMPauseTests: XCTestCase {
    func testPanicBGMPauseDelayElapsedRequiresPanicDomain() {
        let state = panicActiveState()

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .panicBGMPauseDelayElapsed(generation: state.panic.generation, snapshot: state.panic.snapshot!),
            environment: .productionProgramActivationOwning()
        )

        XCTAssertTrue(mutation.state.bgm.isPlaying)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testPanicBGMPauseDelayElapsedIgnoresInactivePanic() {
        var state = panicActiveState()
        state.panic.isActive = false

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .panicBGMPauseDelayElapsed(generation: state.panic.generation, snapshot: state.panic.snapshot!),
            environment: .fullRuntimeForTests()
        )

        XCTAssertTrue(mutation.state.bgm.isPlaying)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testPanicBGMPauseDelayElapsedIgnoresStaleGeneration() {
        let state = panicActiveState()

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .panicBGMPauseDelayElapsed(generation: state.panic.generation - 1, snapshot: state.panic.snapshot!),
            environment: .fullRuntimeForTests()
        )

        XCTAssertTrue(mutation.state.bgm.isPlaying)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testPanicBGMPauseDelayElapsedIgnoresChangedBGM() {
        var state = panicActiveState()
        let replacement = BGMItem(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, title: "Changed", url: URL(fileURLWithPath: "/tmp/changed.mp3"))
        state.bgm.items = [replacement]
        state.bgm.currentID = replacement.id

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .panicBGMPauseDelayElapsed(generation: state.panic.generation, snapshot: state.panic.snapshot!),
            environment: .fullRuntimeForTests()
        )

        XCTAssertTrue(mutation.state.bgm.isPlaying)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testPanicBGMPauseDelayElapsedPausesMatchingBGM() {
        let state = panicActiveState()

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .panicBGMPauseDelayElapsed(generation: state.panic.generation, snapshot: state.panic.snapshot!),
            environment: .fullRuntimeForTests()
        )

        XCTAssertFalse(mutation.state.bgm.isPlaying)
        XCTAssertTrue(mutation.effects.contains(.pauseBGM(generation: state.bgm.generation)))
    }

    func testPanicBGMPauseDelayElapsedAppliesPanicAudioRouting() {
        let state = panicActiveState()

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .panicBGMPauseDelayElapsed(generation: state.panic.generation, snapshot: state.panic.snapshot!),
            environment: .fullRuntimeForTests()
        )

        XCTAssertFalse(mutation.state.audio.routingContext.isBGMPlaying)
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .panicChanged)))
    }

    func testPanicBGMPauseDelayElapsedIsNotLogged() {
        let state = panicActiveState()
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: .fullRuntimeForTests()
        )

        runtime.dispatch(.panicBGMPauseDelayElapsed(generation: state.panic.generation, snapshot: state.panic.snapshot!))

        XCTAssertFalse(LiveRuntimeActionLogPolicy.shouldLog(.panicBGMPauseDelayElapsed(generation: state.panic.generation, snapshot: state.panic.snapshot!)))
        XCTAssertTrue(runtime.actionLog.isEmpty)
    }

    func testPanicBGMPauseDelayElapsedDoesNotRecordSupport() {
        let state = panicActiveState()

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .panicBGMPauseDelayElapsed(generation: state.panic.generation, snapshot: state.panic.snapshot!),
            environment: .fullRuntimeForTests()
        )

        XCTAssertTrue(mutation.state.support.events.isEmpty)
        XCTAssertFalse(mutation.effects.contains(where: { effect in
            if case .recordSupportEvent = effect { return true }
            return false
        }))
    }

    private func panicActiveState() -> LiveRuntimeState {
        let bgm = BGMItem(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, title: "Walk In", url: URL(fileURLWithPath: "/tmp/walk-in.mp3"))
        var state = LiveRuntimeState()
        state.panic.isActive = true
        state.panic.generation = 4
        state.panic.snapshot = PanicPlaybackSnapshot(
            currentProgramID: nil,
            wasMediaPlaying: false,
            currentBGMID: bgm.id,
            wasBGMPlaying: true
        )
        state.bgm.items = [bgm]
        state.bgm.currentID = bgm.id
        state.bgm.isPlaying = true
        state.bgm.generation = 12
        state.audio.routingContext.isBGMPlaying = true
        state.audio.routingContext.isPanicMode = true
        return state
    }
}
