import XCTest
@testable import LiveSwitcher

final class PanicTransitionPolicyTests: XCTestCase {
    func testSnapshotCapturesCurrentProgramID() {
        let program = mediaProgram()

        let snapshot = PanicTransitionPolicy.snapshot(
            currentProgram: program,
            isMediaPlaying: false,
            currentBGM: nil,
            isBGMPlaying: false
        )

        XCTAssertEqual(snapshot.currentProgramID, program.id)
    }

    func testSnapshotCapturesMediaPlayingOnlyForMediaProgram() {
        let snapshot = PanicTransitionPolicy.snapshot(
            currentProgram: mediaProgram(),
            isMediaPlaying: true,
            currentBGM: nil,
            isBGMPlaying: false
        )

        XCTAssertTrue(snapshot.wasMediaPlaying)
    }

    func testSnapshotDoesNotCaptureMediaPlayingForDeckProgram() {
        let snapshot = PanicTransitionPolicy.snapshot(
            currentProgram: deckProgram(),
            isMediaPlaying: true,
            currentBGM: nil,
            isBGMPlaying: false
        )

        XCTAssertFalse(snapshot.wasMediaPlaying)
    }

    func testSnapshotCapturesCurrentBGMID() {
        let bgm = bgmItem()

        let snapshot = PanicTransitionPolicy.snapshot(
            currentProgram: nil,
            isMediaPlaying: false,
            currentBGM: bgm,
            isBGMPlaying: false
        )

        XCTAssertEqual(snapshot.currentBGMID, bgm.id)
    }

    func testSnapshotCapturesBGMPlayingOnlyWhenCurrentBGMExists() {
        let playingSnapshot = PanicTransitionPolicy.snapshot(
            currentProgram: nil,
            isMediaPlaying: false,
            currentBGM: bgmItem(),
            isBGMPlaying: true
        )
        let missingSnapshot = PanicTransitionPolicy.snapshot(
            currentProgram: nil,
            isMediaPlaying: false,
            currentBGM: nil,
            isBGMPlaying: true
        )

        XCTAssertTrue(playingSnapshot.wasBGMPlaying)
        XCTAssertFalse(missingSnapshot.wasBGMPlaying)
    }

    func testShouldPauseMediaForActivationRequiresMatchingProgramID() {
        let program = mediaProgram()
        let different = mediaProgram()
        let snapshot = PanicPlaybackSnapshot(
            currentProgramID: program.id,
            wasMediaPlaying: true,
            currentBGMID: nil,
            wasBGMPlaying: false
        )

        XCTAssertTrue(PanicTransitionPolicy.shouldPauseMediaForActivation(snapshot: snapshot, currentProgram: program))
        XCTAssertFalse(PanicTransitionPolicy.shouldPauseMediaForActivation(snapshot: snapshot, currentProgram: different))
    }

    func testShouldPauseMediaForActivationRequiresMediaProgram() {
        let program = deckProgram()
        let snapshot = PanicPlaybackSnapshot(
            currentProgramID: program.id,
            wasMediaPlaying: true,
            currentBGMID: nil,
            wasBGMPlaying: false
        )

        XCTAssertFalse(PanicTransitionPolicy.shouldPauseMediaForActivation(snapshot: snapshot, currentProgram: program))
    }

    func testShouldPauseBGMAfterFadeRequiresMatchingBGMID() {
        let bgm = bgmItem()
        let different = bgmItem()
        let snapshot = PanicPlaybackSnapshot(
            currentProgramID: nil,
            wasMediaPlaying: false,
            currentBGMID: bgm.id,
            wasBGMPlaying: true
        )

        XCTAssertTrue(PanicTransitionPolicy.shouldPauseBGMAfterFadeForActivation(snapshot: snapshot, currentBGM: bgm))
        XCTAssertFalse(PanicTransitionPolicy.shouldPauseBGMAfterFadeForActivation(snapshot: snapshot, currentBGM: different))
    }

    func testShouldResumeMediaAfterDeactivationRequiresMatchingProgramID() {
        let program = mediaProgram()
        let different = mediaProgram()
        let snapshot = PanicPlaybackSnapshot(
            currentProgramID: program.id,
            wasMediaPlaying: true,
            currentBGMID: nil,
            wasBGMPlaying: false
        )

        XCTAssertTrue(PanicTransitionPolicy.shouldResumeMediaAfterDeactivation(snapshot: snapshot, currentProgram: program))
        XCTAssertFalse(PanicTransitionPolicy.shouldResumeMediaAfterDeactivation(snapshot: snapshot, currentProgram: different))
    }

    func testShouldResumeMediaAfterDeactivationRequiresMediaProgram() {
        let program = deckProgram()
        let snapshot = PanicPlaybackSnapshot(
            currentProgramID: program.id,
            wasMediaPlaying: true,
            currentBGMID: nil,
            wasBGMPlaying: false
        )

        XCTAssertFalse(PanicTransitionPolicy.shouldResumeMediaAfterDeactivation(snapshot: snapshot, currentProgram: program))
    }

    func testShouldResumeBGMAfterDeactivationRequiresMatchingBGMID() {
        let bgm = bgmItem()
        let different = bgmItem()
        let snapshot = PanicPlaybackSnapshot(
            currentProgramID: nil,
            wasMediaPlaying: false,
            currentBGMID: bgm.id,
            wasBGMPlaying: true
        )

        XCTAssertTrue(PanicTransitionPolicy.shouldResumeBGMAfterDeactivation(snapshot: snapshot, currentBGM: bgm))
        XCTAssertFalse(PanicTransitionPolicy.shouldResumeBGMAfterDeactivation(snapshot: snapshot, currentBGM: different))
    }

    func testPolicyDoesNotReferenceSwitcherViewModel() throws {
        XCTAssertFalse(try policySource().contains("SwitcherViewModel"))
    }

    func testPolicyDoesNotReferenceLiveRuntimeStore() throws {
        XCTAssertFalse(try policySource().contains("LiveRuntimeStore"))
    }

    func testPolicyDoesNotDispatchRuntimeActions() throws {
        XCTAssertFalse(try policySource().contains("dispatch"))
    }

    func testPolicyDoesNotCreateTasks() throws {
        XCTAssertFalse(try policySource().contains("Task"))
    }

    func testPolicyDoesNotReferenceFileManager() throws {
        XCTAssertFalse(try policySource().contains("FileManager"))
    }

    private func mediaProgram() -> ProgramItem {
        ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: URL(fileURLWithPath: "/tmp/video.mp4"))
    }

    private func deckProgram() -> ProgramItem {
        ProgramItem(title: "Deck", subtitle: "KEY", sourceURL: URL(fileURLWithPath: "/tmp/deck.key"))
    }

    private func bgmItem() -> BGMItem {
        BGMItem(title: "Walk-in", url: URL(fileURLWithPath: "/tmp/walk-in.mp3"))
    }

    private func policySource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/PanicTransitionPolicy.swift")
    }
}
