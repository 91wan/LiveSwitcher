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

    private func runtimeState(for item: ProgramItem, isPlaying: Bool) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.program.items = [item]
        state.program.currentID = item.id
        state.media.loadedURL = item.sourceURL
        state.media.isPlaying = isPlaying
        state.media.duration = 10
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

    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) {
        events.append("volume:\(generation)")
    }
}
