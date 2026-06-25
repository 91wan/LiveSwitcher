import XCTest
@testable import LiveSwitcher

@MainActor
final class MediaRuntimeSeekTests: XCTestCase {
    func testSeekToStartUsesRuntimeMediaPort() {
        let media = MediaRuntimeSeekPortSpy()
        let viewModel = viewModel(media: media)
        let item = mediaProgram()
        viewModel.applyProgramQueueProjectionFromRuntime([item])
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())
        viewModel.runtime.replaceStateForFacadeSync(runtimeState(for: item, isPlaying: false))

        viewModel.seekProgramItemToStart(item)

        XCTAssertTrue(media.events.contains { $0.hasPrefix("seekStart:") })
    }

    func testSeekToEndUsesRuntimeMediaPort() {
        let media = MediaRuntimeSeekPortSpy()
        let viewModel = viewModel(media: media)
        let item = mediaProgram()
        viewModel.applyProgramQueueProjectionFromRuntime([item])
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())
        viewModel.runtime.replaceStateForFacadeSync(runtimeState(for: item, isPlaying: false))

        viewModel.seekProgramItemToEnd(item)

        XCTAssertTrue(media.events.contains { $0.hasPrefix("seekEnd:") })
    }

    func testSeekToStartDoesNotStartPlaybackIfPaused() {
        let state = runtimeState(for: mediaProgram(), isPlaying: false)

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSeekedCurrentMediaToStart,
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        )

        XCTAssertFalse(mutation.state.media.isPlaying)
        XCTAssertFalse(mutation.effects.contains { effect in
            if case .playMedia = effect { return true }
            return false
        })
    }

    func testSeekToEndDoesNotStartPlaybackIfPaused() {
        let state = runtimeState(for: mediaProgram(), isPlaying: false)

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSeekedCurrentMediaToEnd,
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        )

        XCTAssertFalse(mutation.state.media.isPlaying)
        XCTAssertFalse(mutation.effects.contains { effect in
            if case .playMedia = effect { return true }
            return false
        })
    }

    func testSeekToProgressUpdatesKnownDurationAndKeepsPlaying() {
        let state = runtimeState(for: mediaProgram(), isPlaying: true, currentTime: 2, duration: 20, generation: 7)

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSeekedCurrentMediaToProgress(0.25),
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        )

        XCTAssertTrue(mutation.state.media.isPlaying)
        XCTAssertEqual(mutation.state.media.currentTime, 5, accuracy: 0.0001)
        XCTAssertEqual(mutation.effects, [.seekMediaToProgress(0.25, generation: 7)])
    }

    func testSeekToProgressKeepsPausedState() {
        let state = runtimeState(for: mediaProgram(), isPlaying: false, currentTime: 2, duration: 20, generation: 7)

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSeekedCurrentMediaToProgress(0.75),
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        )

        XCTAssertFalse(mutation.state.media.isPlaying)
        XCTAssertEqual(mutation.state.media.currentTime, 15, accuracy: 0.0001)
        XCTAssertFalse(mutation.effects.contains { effect in
            if case .playMedia = effect { return true }
            return false
        })
    }

    func testSeekToProgressClampsInvalidInputs() {
        let cases: [(input: Double, expected: Double)] = [
            (-0.4, 0),
            (.nan, 0),
            (1.7, 1)
        ]

        for testCase in cases {
            let state = runtimeState(for: mediaProgram(), isPlaying: true, currentTime: 2, duration: 20, generation: 7)

            let mutation = LiveRuntimeReducer.reduce(
                state: state,
                action: .operatorSeekedCurrentMediaToProgress(testCase.input),
                environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
            )

            XCTAssertEqual(mutation.state.media.currentTime, testCase.expected * 20, accuracy: 0.0001)
            XCTAssertEqual(mutation.effects, [.seekMediaToProgress(testCase.expected, generation: 7)])
        }
    }

    func testSeekToProgressWithoutDurationDoesNotInventCurrentTime() {
        let state = runtimeState(for: mediaProgram(), isPlaying: true, currentTime: 3, duration: nil, generation: 7)

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSeekedCurrentMediaToProgress(0.5),
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        )

        XCTAssertEqual(mutation.state.media.currentTime, 3, accuracy: 0.0001)
        XCTAssertEqual(mutation.state.media.duration, nil)
        XCTAssertEqual(mutation.effects, [.seekMediaToProgress(0.5, generation: 7)])
    }

    func testSeekToProgressIgnoresUnseekableCurrentSource() {
        let item = htmlProgram()
        var state = runtimeState(for: item, isPlaying: true, currentTime: 3, duration: 20, generation: 7)
        state.media.loadedURL = item.sourceURL

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSeekedCurrentMediaToProgress(0.5),
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        )

        XCTAssertEqual(mutation.state, state)
        XCTAssertEqual(mutation.effects, [])
    }

    func testViewModelProgressSeekDispatchesRuntimeActionEffectAndPort() {
        let media = MediaRuntimeSeekPortSpy()
        let viewModel = viewModel(media: media)
        let item = mediaProgram()
        viewModel.applyProgramQueueProjectionFromRuntime([item])
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())
        viewModel.runtime.replaceStateForFacadeSync(runtimeState(for: item, isPlaying: true, currentTime: 2, duration: 20, generation: 7))

        viewModel.seekCurrentMedia(toProgress: 0.25, expectedGeneration: 7)

        XCTAssertEqual(viewModel.runtime.actionLog.map(\.actionName), ["operatorSeekedCurrentMediaToProgress"])
        XCTAssertEqual(viewModel.runtime.recordedEffects, [.seekMediaToProgress(0.25, generation: 7)])
        XCTAssertEqual(media.events, ["seekProgress:7:0.25"])
    }

    func testViewModelProgressSeekIgnoresStaleDragGeneration() {
        let media = MediaRuntimeSeekPortSpy()
        let viewModel = viewModel(media: media)
        let item = mediaProgram()
        viewModel.applyProgramQueueProjectionFromRuntime([item])
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())
        viewModel.runtime.replaceStateForFacadeSync(runtimeState(for: item, isPlaying: true, currentTime: 2, duration: 20, generation: 8))

        viewModel.seekCurrentMedia(toProgress: 0.25, expectedGeneration: 7)

        XCTAssertEqual(viewModel.runtime.actionLog, [])
        XCTAssertEqual(viewModel.runtime.recordedEffects, [])
        XCTAssertEqual(media.events, [])
    }

    func testRestartCurrentMediaStillStartsPlayback() {
        let item = mediaProgram()
        let state = runtimeState(for: item, isPlaying: false)

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorRestartedCurrentMedia,
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        )

        XCTAssertTrue(mutation.state.media.isPlaying)
        XCTAssertTrue(mutation.effects.contains { effect in
            if case .restartMedia = effect { return true }
            return false
        })
    }

    func testViewModelDoesNotUseProgramSeekHandlersForMigratedMediaSeek() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramMediaTransport.swift")
        let seekBodies = [
            try sourceFunctionBody(named: "seekProgramItemToStart", inSource: source),
            try sourceFunctionBody(named: "seekProgramItemToEnd", inSource: source)
        ].joined(separator: "\n")

        XCTAssertFalse(seekBodies.contains("programSeekToStartHandler"))
        XCTAssertFalse(seekBodies.contains("programSeekToEndHandler"))
    }

    func testProgressSliderRowDoesNotDirectlySeekAVPlayer() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/RunQueueView.swift")

        XCTAssertTrue(source.contains("ProgressSliderRow"))
        XCTAssertFalse(source.contains("avCoordinator.seek(to:"))
        XCTAssertTrue(source.contains("onSeekProgress"))
    }

    private func viewModel(media: MediaRuntimeSeekPortSpy) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(recordsOnly: false, media: media),
            environment: LiveRuntimeEnvironment(bridgeMode: .mediaOwned)
        )
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
    }

    private func runtimeState(
        for item: ProgramItem,
        isPlaying: Bool,
        currentTime: Double = 0,
        duration: Double? = 10,
        generation: Int = 0
    ) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.program.items = [item]
        state.program.currentID = item.id
        state.media.loadedURL = item.sourceURL
        state.media.isPlaying = isPlaying
        state.media.currentTime = currentTime
        state.media.duration = duration
        state.media.generation = generation
        state.audio.routingContext.isCurrentProgramMediaSource = true
        state.audio.routingContext.isMediaPlaying = isPlaying
        return state
    }

    private func mediaProgram() -> ProgramItem {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        try? Data("fixture".utf8).write(to: url)
        return ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: url)
    }

    private func htmlProgram() -> ProgramItem {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")
        try? Data("<html></html>".utf8).write(to: url)
        return ProgramItem(title: "HTML", subtitle: "HTML", sourceURL: url)
    }

    private func sourceText(_ relativePath: String) throws -> String {
        let url = try repositoryRoot().appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func sourceFunctionBody(named name: String, inSource source: String) throws -> String {
        guard let range = source.range(of: "func \(name)") else {
            XCTFail("Missing function \(name)")
            return ""
        }
        guard let openingBrace = source[range.lowerBound...].firstIndex(of: "{") else {
            XCTFail("Missing body for function \(name)")
            return ""
        }
        var depth = 0
        var index = openingBrace
        while index < source.endIndex {
            if source[index] == "{" {
                depth += 1
            } else if source[index] == "}" {
                depth -= 1
                if depth == 0 {
                    return String(source[openingBrace...index])
                }
            }
            index = source.index(after: index)
        }
        XCTFail("Unterminated function \(name)")
        return ""
    }

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            if FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("script/check_release_hygiene.sh").path
            ) {
                return directory
            }
        }
        throw XCTSkip("Could not locate repository root from test source path.")
    }
}

private final class MediaRuntimeSeekPortSpy: MediaPlaybackPort {
    private(set) var events: [String] = []

    func load(url: URL, generation: Int) {
        events.append("load:\(generation)")
    }

    func play(generation: Int) {
        events.append("play:\(generation)")
    }

    func pause(generation: Int) {
        events.append("pause:\(generation)")
    }

    func restart(generation: Int) {
        events.append("restart:\(generation)")
    }

    func stop(generation: Int) {
        events.append("stop:\(generation)")
    }

    func seekToStart(generation: Int) {
        events.append("seekStart:\(generation)")
    }

    func seekToEnd(generation: Int) {
        events.append("seekEnd:\(generation)")
    }

    func seek(toProgress progress: Double, generation: Int) {
        events.append("seekProgress:\(generation):\(progress)")
    }

    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) {
        events.append("volume:\(generation)")
    }
}
