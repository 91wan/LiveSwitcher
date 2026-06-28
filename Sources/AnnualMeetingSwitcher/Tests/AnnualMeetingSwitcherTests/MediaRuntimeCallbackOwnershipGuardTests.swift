import XCTest
@testable import LiveSwitcher

final class MediaRuntimeCallbackOwnershipGuardTests: XCTestCase {
    func testMediaLoadedNoopsBeforeMediaOwnership() {
        let state = mediaState()
        let mutation = reduce(state, .mediaLoaded(url: URL(fileURLWithPath: "/tmp/new-video.mp4"), generation: 3), bridgeMode: .audioOwned)

        XCTAssertEqual(mutation.state.media, state.media)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testMediaPlaybackChangedNoopsBeforeMediaOwnership() {
        let state = mediaState(mediaPlaying: false)
        let mutation = reduce(state, .mediaPlaybackChanged(isPlaying: true, generation: 3), bridgeMode: .audioOwned)

        XCTAssertEqual(mutation.state.media, state.media)
        XCTAssertEqual(mutation.state.audio, state.audio)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testMediaReachedEndNoopsBeforeMediaOwnership() {
        let state = mediaState(mediaPlaying: true)
        let mutation = reduce(state, .mediaReachedEnd(generation: 3), bridgeMode: .audioOwned)

        XCTAssertEqual(mutation.state.media, state.media)
        XCTAssertEqual(mutation.state.panic, state.panic)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testMediaSeekCompletedNoopsBeforeMediaOwnership() {
        let state = mediaState()
        let mutation = reduce(state, .mediaSeekCompleted(time: 42, generation: 3), bridgeMode: .audioOwned)

        XCTAssertEqual(mutation.state.media, state.media)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testMediaLoadedMutatesWhenMediaOwned() {
        let url = URL(fileURLWithPath: "/tmp/new-video.mp4")
        let mutation = reduce(mediaState(), .mediaLoaded(url: url, generation: 3), bridgeMode: .mediaOwned)

        XCTAssertEqual(mutation.state.media.loadedURL, url)
        XCTAssertFalse(mutation.state.media.didPlayToEnd)
    }

    func testMediaPlaybackChangedMutatesWhenMediaOwned() {
        let mutation = reduce(mediaState(mediaPlaying: false), .mediaPlaybackChanged(isPlaying: true, generation: 3), bridgeMode: .mediaOwned)

        XCTAssertTrue(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.state.audio.routingContext.isMediaPlaying)
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .mediaPlaybackChanged)))
    }

    func testMediaReachedEndMutatesWhenMediaOwned() {
        let mutation = reduce(mediaState(mediaPlaying: true), .mediaReachedEnd(generation: 3), bridgeMode: .mediaOwned)

        XCTAssertFalse(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.state.media.didPlayToEnd)
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .mediaPlaybackChanged)))
    }

    func testMediaSeekCompletedMutatesWhenMediaOwned() {
        let mutation = reduce(mediaState(), .mediaSeekCompleted(time: 42, generation: 3), bridgeMode: .mediaOwned)

        XCTAssertEqual(mutation.state.media.currentTime, 42)
    }

    func testAllMediaCallbackCasesHaveExplicitMediaOwnershipGuard() throws {
        let source = try sourceText(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/Reducers/MediaRuntimeActionDispatcher.swift"
        )

        [
            ".mediaLoaded(let url, let generation)",
            ".mediaPlaybackChanged(let isPlaying, let generation)",
            ".mediaReachedEnd(let generation)",
            ".mediaSeekCompleted(let time, let generation)"
        ].forEach { casePattern in
            assertCase(
                casePattern,
                in: source,
                contains: "guard LiveRuntimeReducer.isRuntimeOwned(.media, in: bridgeMode) else { return true }"
            )
        }
    }

    private func mediaState(mediaPlaying: Bool = true) -> LiveRuntimeState {
        let program = ProgramItem(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            title: "Video",
            subtitle: "MP4",
            sourceURL: URL(fileURLWithPath: "/tmp/video.mp4")
        )
        var state = LiveRuntimeState()
        state.program.items = [program]
        state.program.currentID = program.id
        state.media.loadedURL = program.sourceURL
        state.media.isPlaying = mediaPlaying
        state.media.didPlayToEnd = true
        state.media.currentTime = 12
        state.media.duration = 30
        state.media.generation = 3
        state.audio.routingContext.isCurrentProgramMediaSource = true
        state.audio.routingContext.isMediaPlaying = mediaPlaying
        return state
    }

    private func reduce(
        _ state: LiveRuntimeState,
        _ action: LiveRuntimeAction,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: LiveRuntimeEnvironment(now: Date(timeIntervalSince1970: 100), bridgeMode: bridgeMode)
        )
    }

    private func assertCase(
        _ casePattern: String,
        in source: String,
        contains expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let range = source.range(of: "case \(casePattern):") else {
            return XCTFail("Missing case \(casePattern)", file: file, line: line)
        }
        let endIndex = source.index(range.lowerBound, offsetBy: 360, limitedBy: source.endIndex) ?? source.endIndex
        let body = String(source[range.lowerBound..<endIndex])

        XCTAssertTrue(body.contains(expected), "Missing media ownership guard in \(casePattern)", file: file, line: line)
    }
}
