import XCTest
@testable import LiveSwitcher

final class MediaRuntimeTransportReducerGuardTests: XCTestCase {
    func testToggleMediaPlaybackNoopsWhenNoLoadedURLAndNoCurrentMediaProgram() {
        let state = LiveRuntimeState()

        let mutation = reduce(state, .operatorToggledMediaPlayback)

        XCTAssertEqual(mutation.state, state)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testToggleMediaPlaybackNoopsWhenCurrentProgramIsHTMLAndNoLoadedURL() {
        let html = htmlProgram()
        var state = LiveRuntimeState()
        state.program.items = [html]
        state.program.currentID = html.id

        let mutation = reduce(state, .operatorToggledMediaPlayback)

        XCTAssertEqual(mutation.state, state)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testToggleMediaPlaybackCanPauseWhenMediaIsLoadedEvenIfCurrentProgramMissing() {
        var state = LiveRuntimeState()
        state.media.loadedURL = URL(fileURLWithPath: "/tmp/loaded.mp4")
        state.media.isPlaying = true
        state.media.generation = 4

        let mutation = reduce(state, .operatorToggledMediaPlayback)

        XCTAssertFalse(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.effects.contains(.pauseMedia(generation: 4)))
    }

    func testToggleMediaPlaybackCanPlayWhenCurrentProgramIsMedia() {
        let media = mediaProgram()
        var state = LiveRuntimeState()
        state.program.items = [media]
        state.program.currentID = media.id
        state.media.generation = 4

        let mutation = reduce(state, .operatorToggledMediaPlayback)

        XCTAssertTrue(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.effects.contains(.playMedia(generation: 4)))
    }

    func testToggleMediaPlaybackDuringPanicStillPausesOnlyWhenMediaContextExists() {
        var noContext = LiveRuntimeState()
        noContext.panic.isActive = true
        noContext.media.isPlaying = true
        noContext.media.generation = 4

        let rejected = reduce(noContext, .operatorToggledMediaPlayback)

        XCTAssertEqual(rejected.state, noContext)
        XCTAssertTrue(rejected.effects.isEmpty)

        var loaded = noContext
        loaded.media.loadedURL = URL(fileURLWithPath: "/tmp/loaded.mp4")

        let accepted = reduce(loaded, .operatorToggledMediaPlayback)

        XCTAssertFalse(accepted.state.media.isPlaying)
        XCTAssertTrue(accepted.effects.contains(.pauseMedia(generation: 4)))
        XCTAssertFalse(accepted.effects.contains { if case .playMedia = $0 { return true }; return false })
    }

    func testMediaRuntimeReducerHasMediaPlaybackContextGuard() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/MediaRuntimeReducer.swift"
        )

        XCTAssertTrue(source.contains("hasMediaPlaybackContext"))
        XCTAssertTrue(source.contains("guard hasMediaPlaybackContext(state) else { return }"))
    }

    private func reduce(_ state: LiveRuntimeState, _ action: LiveRuntimeAction) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: .fullRuntimeForTests(liveAudioFadeDuration: 0)
        )
    }

    private func mediaProgram() -> ProgramItem {
        ProgramItem(
            title: "Video",
            subtitle: "VIDEO",
            sourceURL: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).mp4")
        )
    }

    private func htmlProgram() -> ProgramItem {
        ProgramItem(
            title: "HTML",
            subtitle: "HTML",
            sourceURL: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).html")
        )
    }
}
