import XCTest
@testable import LiveSwitcher

final class BGMRuntimePanicSnapshotIntegrationTests: XCTestCase {
    func testSelectedBGMDuringPanicMarksSnapshotBGMStopped() {
        var state = panicState()
        let next = bgmItem(title: "Next")
        state.bgm.items.append(next)
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.selectBGM(id: next.id, state: &state, effects: &effects)

        XCTAssertFalse(state.panic.snapshot?.wasBGMPlaying == true)
    }

    func testStoppedBGMDuringPanicMarksSnapshotBGMStopped() {
        var state = panicState()
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.stop(
            state: &state,
            effects: &effects,
            liveAudioFadeDuration: 0.4,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertFalse(state.panic.snapshot?.wasBGMPlaying == true)
    }

    func testBGMReachedEndDuringPanicMarksSnapshotBGMStopped() {
        var state = panicState()
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.reachedEnd(
            generation: 7,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertFalse(state.panic.snapshot?.wasBGMPlaying == true)
    }

    func testBGMFailedDuringPanicMarksSnapshotBGMStopped() {
        var state = panicState()
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.failed(
            reason: "decode",
            generation: 7,
            state: &state,
            effects: &effects,
            canWriteSupport: false,
            now: Date(timeIntervalSince1970: 100),
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertFalse(state.panic.snapshot?.wasBGMPlaying == true)
    }

    func testPausedBGMForPanicDoesNotMarkSnapshotBGMStopped() {
        var state = panicState()
        var effects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.pauseForPanic(
            generation: 7,
            state: &state,
            effects: &effects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )

        XCTAssertTrue(state.panic.snapshot?.wasBGMPlaying == true)
    }

    func testPanicOffDoesNotResumeBGMAfterSelectedNewBGMDuringPanic() {
        var state = panicState()
        let next = bgmItem(title: "Next")
        state.bgm.items.append(next)
        var selectEffects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.selectBGM(id: next.id, state: &state, effects: &selectEffects)
        let off = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSetPanic(false),
            environment: .fullRuntimeForTests(liveAudioFadeDuration: 0)
        )

        XCTAssertFalse(off.state.bgm.isPlaying)
        XCTAssertFalse(off.effects.contains { if case .playBGM = $0 { return true }; return false })
    }

    func testPanicOffStillResumesBGMAfterNormalPanicPause() {
        var state = panicState()
        var pauseEffects: [LiveRuntimeEffect] = []

        BGMRuntimeReducer.pauseForPanic(
            generation: 7,
            state: &state,
            effects: &pauseEffects,
            speakerModeDuckedRatio: AudioRoutingDefaults.speakerModeDuckedRatio
        )
        let off = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSetPanic(false),
            environment: .fullRuntimeForTests(liveAudioFadeDuration: 0)
        )

        XCTAssertTrue(off.state.bgm.isPlaying)
        XCTAssertTrue(off.effects.contains(.playBGM(generation: 7)))
    }

    private func panicState() -> LiveRuntimeState {
        let bgm = bgmItem(title: "Walk In")
        var state = LiveRuntimeState()
        state.bgm.items = [bgm]
        state.bgm.currentID = bgm.id
        state.bgm.isPlaying = true
        state.bgm.generation = 7
        state.panic.isActive = true
        state.panic.snapshot = PanicPlaybackSnapshot(
            currentProgramID: nil,
            wasMediaPlaying: false,
            currentBGMID: bgm.id,
            wasBGMPlaying: true
        )
        return state
    }

    private func bgmItem(title: String) -> BGMItem {
        BGMItem(
            id: UUID(),
            title: title,
            url: URL(fileURLWithPath: "/tmp/\(title).mp3")
        )
    }
}
