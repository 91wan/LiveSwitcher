import XCTest
@testable import LiveSwitcher

@MainActor
final class MediaRuntimeOwnershipTests: XCTestCase {
    func testToggleMainVideoPlaybackUsesRuntimeMediaPort() {
        let media = MediaRuntimeOwnershipPortSpy()
        let viewModel = viewModel(media: media)
        let item = mediaProgram()
        viewModel.applyProgramQueueProjectionFromRuntime([item])
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())
        viewModel.runtime.replaceStateForFacadeSync(runtimeState(for: item, isPlaying: false))

        viewModel.toggleMainVideoPlayback()

        XCTAssertTrue(media.events.contains { $0 == "play:0" || $0.hasPrefix("play:") })
    }

    func testRestartCurrentMediaUsesRuntimeMediaPort() {
        let media = MediaRuntimeOwnershipPortSpy()
        let viewModel = viewModel(media: media)
        let item = mediaProgram()
        viewModel.applyProgramQueueProjectionFromRuntime([item])
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())
        viewModel.runtime.replaceStateForFacadeSync(runtimeState(for: item, isPlaying: true))

        viewModel.restartCurrentMediaFromBeginning()

        XCTAssertTrue(media.events.contains { $0.hasPrefix("restart:") })
    }

    func testSwitchToMediaProgramUsesRuntimeLoadAndPlayEffects() {
        let media = MediaRuntimeOwnershipPortSpy()
        let viewModel = viewModel(media: media, bridgeMode: .programActivationOwned)
        let item = mediaProgram()
        viewModel.addProgramItem(item)

        viewModel.switchToProgram(item)

        XCTAssertTrue(media.events.contains { $0.hasPrefix("load:") })
        XCTAssertTrue(media.events.contains { $0.hasPrefix("play:") })
    }

    func testSwitchToMediaProgramDoesNotCallAVPlayerDirectlyFromViewModel() throws {
        let body = try sourceFunctionBody(
            named: "switchToProgram",
            in: programActivationExtensionPath
        )

        XCTAssertFalse(body.contains("avCoordinator.load("))
        XCTAssertFalse(body.contains("avCoordinator.play("))
        XCTAssertFalse(body.contains("avCoordinator.pause("))
    }

    func testRemoveCurrentMediaProgramStopsMediaThroughRuntime() {
        let media = MediaRuntimeOwnershipPortSpy()
        let viewModel = viewModel(media: media)
        let item = mediaProgram()
        viewModel.applyProgramQueueProjectionFromRuntime([item])
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())
        viewModel.runtime.replaceStateForFacadeSync(runtimeState(for: item, isPlaying: true))

        viewModel.removeProgramItem(withID: item.id)

        XCTAssertTrue(media.events.contains { $0.hasPrefix("stop:") })
    }

    func testSeekToStartUsesRuntimeOrIsExplicitlyDocumented() throws {
        let body = try sourceFunctionBody(
            named: "seekProgramItemToStart",
            in: programMediaTransportExtensionPath
        )

        XCTAssertTrue(
            body.contains("dispatchRuntimeFacadeAction") || body.contains("not migrated"),
            "seekProgramItemToStart must use runtime or be explicitly documented as not migrated."
        )
    }

    func testSeekToEndUsesRuntimeOrIsExplicitlyDocumented() throws {
        let body = try sourceFunctionBody(
            named: "seekProgramItemToEnd",
            in: programMediaTransportExtensionPath
        )

        XCTAssertTrue(
            body.contains("dispatchRuntimeFacadeAction") || body.contains("not migrated"),
            "seekProgramItemToEnd must use runtime or be explicitly documented as not migrated."
        )
    }

    func testViewModelDoesNotDirectlyCallAVPlayerForMediaTransport() throws {
        let source = try sourceText(programMediaTransportExtensionPath)
        let queueSource = try sourceText(programQueueMutationPath)
        let transportBodies = [
            try sourceFunctionBody(named: "toggleMainVideoPlayback", inSource: source),
            try sourceFunctionBody(named: "restartCurrentMediaFromBeginning", inSource: source),
            try sourceFunctionBody(named: "removeProgramItem", inSource: queueSource)
        ].joined(separator: "\n")

        XCTAssertFalse(transportBodies.contains("avCoordinator.play("))
        XCTAssertFalse(transportBodies.contains("avCoordinator.pause("))
        XCTAssertFalse(transportBodies.contains("avCoordinator.stop("))
        XCTAssertFalse(transportBodies.contains("programRestartFromBeginningHandler"))
    }

    private func viewModel(
        media: MediaRuntimeOwnershipPortSpy,
        bridgeMode: LiveRuntimeBridgeMode = .mediaOwned
    ) -> SwitcherViewModel {
        let programActivation = ClosureProgramActivationPort()
        let runtime = LiveRuntimeStore(
            effectRunner: LiveRuntimeEffectRunner(
                recordsOnly: false,
                media: media,
                programActivation: programActivation
            ),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        programActivation.executeHandler = { [weak viewModel] id, plan, context in
            viewModel?.executeProgramActivationPlanFromRuntime(id: id, plan: plan, context: context)
        }
        return viewModel
    }

    private func runtimeState(for item: ProgramItem, isPlaying: Bool) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.program.items = [item]
        state.program.currentID = item.id
        state.media.loadedURL = item.sourceURL
        state.media.isPlaying = isPlaying
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

    private var programActivationExtensionPath: String {
        "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramActivation.swift"
    }

    private var programMediaTransportExtensionPath: String {
        "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramMediaTransport.swift"
    }

    private var programQueueMutationPath: String {
        "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramQueue.swift"
    }

    private func sourceFunctionBody(named name: String, in relativePath: String) throws -> String {
        try sourceFunctionBody(named: name, inSource: sourceText(relativePath))
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

private final class MediaRuntimeOwnershipPortSpy: MediaPlaybackPort {
    private(set) var events: [String] = []

    func load(url: URL, generation: Int) {
        events.append("load:\(generation):\(url.lastPathComponent)")
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

    func seekToStart(generation: Int) {
        events.append("seekToStart:\(generation)")
    }

    func seekToEnd(generation: Int) {
        events.append("seekToEnd:\(generation)")
    }

    func stop(generation: Int) {
        events.append("stop:\(generation)")
    }

    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) {
        events.append("volume:\(generation):\(volume):\(fade)")
    }
}
