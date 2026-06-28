import XCTest
@testable import LiveSwitcher

final class MediaRuntimeReducerExtractionTests: XCTestCase {
    func testMediaRuntimeReducerFileExists() throws {
        _ = try mediaReducerSource()
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
        try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/Reducers/MediaRuntimeActionDispatcher.swift")
    }
}
