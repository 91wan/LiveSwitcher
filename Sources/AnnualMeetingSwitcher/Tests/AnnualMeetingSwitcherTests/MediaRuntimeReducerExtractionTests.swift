import XCTest
@testable import LiveSwitcher

final class MediaRuntimeReducerExtractionTests: XCTestCase {
    func testMediaRuntimeReducerFileExists() throws {
        _ = try mediaReducerSource()
    }

    func testMediaRuntimeReducerOwnsTogglePlaybackLogic() throws {
        let source = try mediaReducerSource()

        XCTAssertTrue(source.contains("static func togglePlayback"))
        XCTAssertTrue(source.contains("state.media.isPlaying.toggle()"))
    }

    func testMediaRuntimeReducerOwnsRestartLogic() throws {
        let source = try mediaReducerSource()

        XCTAssertTrue(source.contains("static func restartCurrent"))
        XCTAssertTrue(source.contains(".restartMedia"))
        XCTAssertTrue(source.contains(".seekMediaToStart"))
    }

    func testMediaRuntimeReducerOwnsSeekLogic() throws {
        let source = try mediaReducerSource()

        XCTAssertTrue(source.contains("static func seekCurrentToStart"))
        XCTAssertTrue(source.contains("static func seekCurrentToEnd"))
        XCTAssertTrue(source.contains(".seekMediaToEnd"))
    }

    func testMediaRuntimeReducerOwnsStopLogic() throws {
        let source = try mediaReducerSource()

        XCTAssertTrue(source.contains("static func stopCurrent"))
        XCTAssertTrue(source.contains("state.media.loadedURL = nil"))
        XCTAssertTrue(source.contains(".stopMedia"))
    }

    func testMediaRuntimeReducerOwnsPanicPauseResumeLogic() throws {
        let source = try mediaReducerSource()

        XCTAssertTrue(source.contains("static func pauseForPanic"))
        XCTAssertTrue(source.contains("static func resumeAfterPanic"))
        XCTAssertTrue(source.contains(".setMediaVolume(0, fade: 0"))
    }

    func testMediaRuntimeReducerOwnsCallbackLogic() throws {
        let source = try mediaReducerSource()

        XCTAssertTrue(source.contains("static func loaded"))
        XCTAssertTrue(source.contains("static func playbackChanged"))
        XCTAssertTrue(source.contains("static func reachedEnd"))
        XCTAssertTrue(source.contains("static func seekCompleted"))
    }

    func testLiveRuntimeReducerDelegatesMediaToggle() throws {
        let source = try liveReducerSource()

        XCTAssertTrue(source.contains("MediaRuntimeReducer.togglePlayback"))
    }

    func testLiveRuntimeReducerDelegatesMediaRestart() throws {
        let source = try liveReducerSource()

        XCTAssertTrue(source.contains("MediaRuntimeReducer.restartCurrent"))
    }

    func testLiveRuntimeReducerDelegatesMediaStop() throws {
        let source = try liveReducerSource()

        XCTAssertTrue(source.contains("MediaRuntimeReducer.stopCurrent"))
    }

    func testLiveRuntimeReducerDelegatesMediaReachedEnd() throws {
        let source = try liveReducerSource()

        XCTAssertTrue(source.contains("MediaRuntimeReducer.reachedEnd"))
    }

    func testLiveRuntimeReducerDelegatesMediaPlaybackChanged() throws {
        let source = try liveReducerSource()

        XCTAssertTrue(source.contains("MediaRuntimeReducer.playbackChanged"))
    }

    func testLiveRuntimeReducerDoesNotContainMediaToggleMutationBody() throws {
        let source = try liveReducerSource()
        let body = try XCTUnwrap(source.slice(
            from: "case .operatorToggledMediaPlayback:",
            to: "case .operatorRestartedCurrentMedia:"
        ))

        XCTAssertFalse(body.contains("state.media.isPlaying.toggle()"))
        XCTAssertFalse(body.contains(".playMedia"))
        XCTAssertFalse(body.contains(".pauseMedia"))
    }

    func testLiveRuntimeReducerDoesNotContainMediaRestartMutationBody() throws {
        let source = try liveReducerSource()
        let body = try XCTUnwrap(source.slice(
            from: "case .operatorRestartedCurrentMedia:",
            to: "case .operatorSeekedCurrentMediaToStart:"
        ))

        XCTAssertFalse(body.contains("state.media.didPlayToEnd = false"))
        XCTAssertFalse(body.contains("state.media.currentTime = 0"))
        XCTAssertFalse(body.contains(".restartMedia"))
        XCTAssertFalse(body.contains(".seekMediaToStart"))
    }

    func testLiveRuntimeReducerDoesNotContainMediaStopMutationBody() throws {
        let source = try liveReducerSource()
        let body = try XCTUnwrap(source.slice(
            from: "case .operatorStoppedCurrentMedia:",
            to: "case .operatorPausedMediaForPanic"
        ))

        XCTAssertFalse(body.contains("state.media.loadedURL = nil"))
        XCTAssertFalse(body.contains("state.media.duration = nil"))
        XCTAssertFalse(body.contains(".stopMedia"))
    }

    func testLiveRuntimeReducerDoesNotCallPanicMediaSnapshotHelperDirectly() throws {
        let source = try liveReducerSource()

        XCTAssertFalse(source.contains("PanicRuntimeReducer.markMediaStoppedIfCurrentProgramMatchesSnapshot"))
    }

    func testLiveRuntimeReducerDoesNotContainMediaPlaybackChangedMutationBody() throws {
        let source = try liveReducerSource()
        let body = try XCTUnwrap(source.slice(
            from: "case .mediaPlaybackChanged",
            to: "case .mediaReachedEnd"
        ))

        XCTAssertFalse(body.contains("state.media.isPlaying"))
        XCTAssertFalse(body.contains("state.audio.routingContext.isMediaPlaying"))
        XCTAssertFalse(body.contains(".pauseMedia"))
        XCTAssertFalse(body.contains(".playMedia"))
    }

    func testMediaRuntimeReducerMayCallRuntimeAudioHelpers() throws {
        let source = try mediaReducerSource()

        XCTAssertTrue(source.contains("AudioRuntimeReducer.syncRoutingContextFromMirrorState"))
        XCTAssertTrue(source.contains("AudioRuntimeReducer.recalculateAudio"))
    }

    func testViewModelFilesDoNotCallLiveRuntimeReducerRecalculateAudio() throws {
        for relativePath in runtimeFacadeViewModelFiles {
            let source = try repositorySource(relativePath)

            XCTAssertFalse(source.contains("LiveRuntimeReducer.recalculateAudio"), relativePath)
        }
    }

    func testViewModelFilesDoNotCallLiveRuntimeReducerSyncAudioRoutingContext() throws {
        for relativePath in runtimeFacadeViewModelFiles {
            let source = try repositorySource(relativePath)

            XCTAssertFalse(source.contains("LiveRuntimeReducer.syncAudioRoutingContext"), relativePath)
        }
    }

    func testAudioReducerExtractionIsComplete() throws {
        let docs = try repositorySource("docs/architecture/runtime-ownership.md")

        XCTAssertTrue(docs.localizedStandardContains("AudioRuntimeReducer"))
        XCTAssertFalse(docs.contains("AudioRuntimeReducer extraction remains future work"))
        XCTAssertNotNil(try optionalRepositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/AudioRuntimeReducer.swift"
        ))
    }

    private func mediaReducerSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/MediaRuntimeReducer.swift")
    }

    private func liveReducerSource() throws -> String {
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")
    }

    private var runtimeFacadeViewModelFiles: [String] {
        [
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramMediaTransport.swift",
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+MediaPlayback.swift",
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeFacade.swift",
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeFacadeSync.swift",
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeSnapshot.swift"
        ]
    }
}
