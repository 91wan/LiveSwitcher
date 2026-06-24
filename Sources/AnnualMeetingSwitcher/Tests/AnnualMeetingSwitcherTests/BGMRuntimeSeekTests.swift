import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMRuntimeSeekTests: XCTestCase {
    func testSeekBGMToBeginningUsesRuntimePort() {
        var state = bgmState(progress: 0.7, currentTime: 14, duration: 20)

        let mutation = reduce(&state, .operatorSeekedBGMToBeginning)

        XCTAssertEqual(mutation.state.bgm.progress, 0)
        XCTAssertEqual(mutation.state.bgm.currentTime, 0)
        XCTAssertEqual(mutation.effects, [.seekBGMToBeginning(generation: 3)])
    }

    func testSeekBGMToProgressUsesRuntimePort() {
        var state = bgmState(progress: 0, currentTime: 0, duration: 20)

        let mutation = reduce(&state, .operatorSeekedBGMToProgress(0.25))

        XCTAssertEqual(mutation.state.bgm.progress, 0.25, accuracy: 0.0001)
        XCTAssertEqual(mutation.state.bgm.currentTime, 5, accuracy: 0.0001)
        XCTAssertEqual(mutation.effects, [.seekBGMToProgress(0.25, generation: 3)])
    }

    func testSeekBGMToBeginningDoesNotStartPlayback() {
        var state = bgmState(isPlaying: false, progress: 0.7, currentTime: 14, duration: 20)

        let mutation = reduce(&state, .operatorSeekedBGMToBeginning)

        XCTAssertFalse(mutation.state.bgm.isPlaying)
        XCTAssertFalse(mutation.effects.contains(.playBGM(generation: 3)))
    }

    func testSeekBGMToProgressDoesNotStartPlayback() {
        var state = bgmState(isPlaying: false, progress: 0, currentTime: 0, duration: 20)

        let mutation = reduce(&state, .operatorSeekedBGMToProgress(0.5))

        XCTAssertFalse(mutation.state.bgm.isPlaying)
        XCTAssertFalse(mutation.effects.contains(.playBGM(generation: 3)))
    }

    func testSeekBGMProgressIsClamped() {
        var state = bgmState(progress: 0, currentTime: 0, duration: 20)

        let mutation = reduce(&state, .operatorSeekedBGMToProgress(1.7))

        XCTAssertEqual(mutation.state.bgm.progress, 1)
        XCTAssertEqual(mutation.state.bgm.currentTime, 20)
        XCTAssertEqual(mutation.effects, [.seekBGMToProgress(1, generation: 3)])
    }

    func testStaleBGMSeekToBeginningEffectIsIgnored() {
        let port = BGMRuntimeSeekPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, bgm: port)
        let state = bgmState(generation: 5)

        runner.run([.seekBGMToBeginning(generation: 4)], currentState: { state }, dispatch: { _ in })

        XCTAssertEqual(port.seekToBeginningGenerations, [])
    }

    func testStaleBGMSeekToProgressEffectIsIgnored() {
        let port = BGMRuntimeSeekPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, bgm: port)
        let state = bgmState(generation: 5)

        runner.run([.seekBGMToProgress(0.4, generation: 4)], currentState: { state }, dispatch: { _ in })

        XCTAssertEqual(port.seekToProgressCalls.map(\.generation), [])
    }

    func testViewModelSeekBGMDoesNotDirectlyMutatePlayers() throws {
        let source = try sourceText("ViewModel+BGMControls.swift")
        let beginningBody = try functionBody(named: "seekBGMToBeginning", in: source)
        let progressBody = try functionBody(named: "seekBGM(toProgress progress: Double)", in: source)

        XCTAssertFalse(beginningBody.contains("bgmAudioPlayer?.currentTime"))
        XCTAssertFalse(beginningBody.contains("bgmFallbackPlayer.seek"))
        XCTAssertFalse(progressBody.contains("player.currentTime"))
        XCTAssertFalse(progressBody.contains("bgmFallbackPlayer.seek"))
    }

    private func reduce(_ state: inout LiveRuntimeState, _ action: LiveRuntimeAction) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: .productionBGMOwning()
        )
    }

    private func bgmState(
        generation: Int = 3,
        isPlaying: Bool = true,
        progress: Double = 0,
        currentTime: Double = 0,
        duration: Double? = nil
    ) -> LiveRuntimeState {
        let item = BGMItem(title: "Walk-in", url: URL(fileURLWithPath: "/tmp/walk-in.mp3"))
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        state.bgm.currentID = item.id
        state.bgm.generation = generation
        state.bgm.phase = isPlaying ? .playing : .selected
        state.bgm.progress = progress
        state.bgm.currentTime = currentTime
        state.bgm.duration = duration
        return state
    }

    private func functionBody(named signature: String, in source: String) throws -> String {
        guard let start = source.range(of: "func \(signature)") else {
            XCTFail("Function \(signature) not found")
            return ""
        }
        guard let bodyStart = source[start.lowerBound...].firstIndex(of: "{") else {
            XCTFail("Function \(signature) body not found")
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
        XCTFail("Function \(signature) body was not closed")
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

private final class BGMRuntimeSeekPortSpy: BGMPlaybackPort {
    private(set) var seekToBeginningGenerations: [Int] = []
    private(set) var seekToProgressCalls: [(progress: Double, generation: Int)] = []

    func prepare(item: BGMItem, generation: Int) {}
    func play(generation: Int) {}
    func pause(generation: Int) {}
    func stop(fade: TimeInterval, generation: Int) {}
    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) {}
    func seekToBeginning(generation: Int) { seekToBeginningGenerations.append(generation) }
    func seek(toProgress progress: Double, generation: Int) {
        seekToProgressCalls.append((progress, generation))
    }
    func setPlayMode(_ playMode: BGMPlayMode, generation: Int?) {}
}
