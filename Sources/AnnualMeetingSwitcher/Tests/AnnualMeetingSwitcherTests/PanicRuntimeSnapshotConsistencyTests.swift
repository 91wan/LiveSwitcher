import XCTest
@testable import LiveSwitcher

final class PanicRuntimeSnapshotConsistencyTests: XCTestCase {
    func testRuntimeMarkMediaStoppedRequiresPanicActive() {
        var state = panicState(isActive: false)

        PanicRuntimeReducer.markMediaStoppedIfCurrentProgramMatchesSnapshot(state: &state)

        XCTAssertTrue(state.panic.snapshot?.wasMediaPlaying == true)
    }

    func testRuntimeMarkMediaStoppedRequiresMatchingCurrentProgram() {
        var state = panicState()
        state.program.currentID = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!

        PanicRuntimeReducer.markMediaStoppedIfCurrentProgramMatchesSnapshot(state: &state)

        XCTAssertTrue(state.panic.snapshot?.wasMediaPlaying == true)
    }

    func testRuntimeMarkMediaStoppedClearsWasMediaPlaying() {
        var state = panicState()

        PanicRuntimeReducer.markMediaStoppedIfCurrentProgramMatchesSnapshot(state: &state)

        XCTAssertFalse(state.panic.snapshot?.wasMediaPlaying == true)
    }

    func testRuntimeMarkMediaStoppedDoesNotClearDifferentProgramSnapshot() {
        var state = panicState()
        state.panic.snapshot = PanicPlaybackSnapshot(
            currentProgramID: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!,
            wasMediaPlaying: true,
            currentBGMID: bgmID,
            wasBGMPlaying: true
        )

        PanicRuntimeReducer.markMediaStoppedIfCurrentProgramMatchesSnapshot(state: &state)

        XCTAssertTrue(state.panic.snapshot?.wasMediaPlaying == true)
    }

    func testRuntimeMarkBGMStoppedRequiresPanicActive() {
        var state = panicState(isActive: false)

        PanicRuntimeReducer.markBGMStoppedIfCurrentBGMMatchesSnapshot(state: &state)

        XCTAssertTrue(state.panic.snapshot?.wasBGMPlaying == true)
    }

    func testRuntimeMarkBGMStoppedRequiresMatchingCurrentBGM() {
        var state = panicState()
        state.bgm.currentID = UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!

        PanicRuntimeReducer.markBGMStoppedIfCurrentBGMMatchesSnapshot(state: &state)

        XCTAssertTrue(state.panic.snapshot?.wasBGMPlaying == true)
    }

    func testRuntimeMarkBGMStoppedClearsWasBGMPlaying() {
        var state = panicState()

        PanicRuntimeReducer.markBGMStoppedIfCurrentBGMMatchesSnapshot(state: &state)

        XCTAssertFalse(state.panic.snapshot?.wasBGMPlaying == true)
    }

    func testRuntimeMarkBGMStoppedDoesNotClearDifferentBGMSnapshot() {
        var state = panicState()
        state.panic.snapshot = PanicPlaybackSnapshot(
            currentProgramID: programID,
            wasMediaPlaying: true,
            currentBGMID: UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!,
            wasBGMPlaying: true
        )

        PanicRuntimeReducer.markBGMStoppedIfCurrentBGMMatchesSnapshot(state: &state)

        XCTAssertTrue(state.panic.snapshot?.wasBGMPlaying == true)
    }

    func testPanicSnapshotMutationHelpersLiveInPanicRuntimeReducer() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/PanicRuntimeReducer.swift")

        XCTAssertTrue(source.contains("markMediaStoppedIfCurrentProgramMatchesSnapshot"))
        XCTAssertTrue(source.contains("markBGMStoppedIfCurrentBGMMatchesSnapshot"))
    }

    func testLiveRuntimeReducerDoesNotDeclarePanicSnapshotBGMHelper() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")

        XCTAssertFalse(source.contains("markPanicSnapshotBGMStoppedIfNeeded"))
    }

    private let programID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    private let bgmID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!

    private func panicState(isActive: Bool = true) -> LiveRuntimeState {
        let program = ProgramItem(
            id: programID,
            title: "Video",
            subtitle: "MP4",
            sourceURL: URL(fileURLWithPath: "/tmp/video.mp4")
        )
        let bgm = BGMItem(
            id: bgmID,
            title: "Walk In",
            url: URL(fileURLWithPath: "/tmp/walk-in.mp3")
        )
        var state = LiveRuntimeState()
        state.program.items = [program]
        state.program.currentID = program.id
        state.bgm.items = [bgm]
        state.bgm.currentID = bgm.id
        state.panic.isActive = isActive
        state.panic.snapshot = PanicPlaybackSnapshot(
            currentProgramID: program.id,
            wasMediaPlaying: true,
            currentBGMID: bgm.id,
            wasBGMPlaying: true
        )
        return state
    }
}
