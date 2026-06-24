import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMRuntimeLoopModeTests: XCTestCase {
    func testToggleLoopModeDispatchesRuntimeAction() {
        let viewModel = makeViewModel()
        viewModel.bgmPlayMode = .loopAll

        viewModel.toggleLoopMode()

        XCTAssertEqual(viewModel.bgmPlayMode, .loopOne)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorSelectedBGMPlayMode" })
    }

    func testLoopModeEffectCallsBGMPort() {
        let port = BGMRuntimeLoopModePortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, bgm: port)
        var state = LiveRuntimeState()
        state.bgm.generation = 7

        runner.run([.setBGMPlayMode(.loopOne, generation: 7)], currentState: { state }, dispatch: { _ in })

        XCTAssertEqual(port.playModeCalls, [.loopOne])
    }

    func testLoopModePersistsThroughPersistenceEffect() {
        let mutation = LiveRuntimeReducer.reduce(
            state: LiveRuntimeState(),
            action: .operatorSelectedBGMPlayMode(.sequential),
            environment: .productionBGMOwning()
        )

        XCTAssertTrue(mutation.effects.contains(.saveBGMPlayMode(.sequential)))
    }

    func testToggleLoopModeDoesNotDirectlyMutateBGMPlayer() throws {
        let source = try sourceText("ViewModel+BGMControls.swift")
        let body = try functionBody(named: "toggleLoopMode", in: source)

        XCTAssertFalse(body.contains("bgmAudioPlayer?.numberOfLoops"))
        XCTAssertFalse(body.contains("numberOfLoops ="))
    }

    func testLoopModeDoesNotChangeCurrentBGMPlaybackState() {
        var state = LiveRuntimeState()
        let item = BGMItem(title: "Walk-in", url: URL(fileURLWithPath: "/tmp/walk-in.mp3"))
        state.bgm.items = [item]
        state.bgm.currentID = item.id
        state.bgm.phase = .playing
        state.bgm.progress = 0.4
        state.bgm.currentTime = 8
        state.bgm.duration = 20
        state.bgm.generation = 11

        let mutation = LiveRuntimeReducer.reduce(
            state: state,
            action: .operatorSelectedBGMPlayMode(.loopOne),
            environment: .productionBGMOwning()
        )

        XCTAssertEqual(mutation.state.bgm.currentID, item.id)
        XCTAssertTrue(mutation.state.bgm.isPlaying)
        XCTAssertEqual(mutation.state.bgm.progress, 0.4, accuracy: 0.0001)
        XCTAssertEqual(mutation.state.bgm.currentTime, 8, accuracy: 0.0001)
        XCTAssertEqual(mutation.state.bgm.generation, 11)
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "BGMRuntimeLoopModeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
    }

    private func functionBody(named name: String, in source: String) throws -> String {
        guard let start = source.range(of: "func \(name)") else {
            XCTFail("Function \(name) not found")
            return ""
        }
        guard let bodyStart = source[start.lowerBound...].firstIndex(of: "{") else {
            XCTFail("Function \(name) body not found")
            return ""
        }
        var depth = 0
        var index = bodyStart
        while index < source.endIndex {
            if source[index] == "{" { depth += 1 }
            if source[index] == "}" {
                depth -= 1
                if depth == 0 {
                    return String(source[bodyStart...index])
                }
            }
            index = source.index(after: index)
        }
        XCTFail("Function \(name) body was not closed")
        return ""
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let candidates = [
            packageRoot.appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher").appendingPathComponent(relativePath),
            packageRoot.appendingPathComponent("Sources/AnnualMeetingSwitcher").appendingPathComponent(relativePath),
            packageRoot.appendingPathComponent(relativePath)
        ]
        if let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return url
        }
        return candidates[0]
    }
}

private final class BGMRuntimeLoopModePortSpy: BGMPlaybackPort {
    private(set) var playModeCalls: [BGMPlayMode] = []

    func prepare(item: BGMItem, generation: Int) {}
    func play(generation: Int) {}
    func pause(generation: Int) {}
    func stop(fade: TimeInterval, generation: Int) {}
    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) {}
    func seekToBeginning(generation: Int) {}
    func seek(toProgress progress: Double, generation: Int) {}
    func setPlayMode(_ playMode: BGMPlayMode, generation: Int?) {
        playModeCalls.append(playMode)
    }
}
