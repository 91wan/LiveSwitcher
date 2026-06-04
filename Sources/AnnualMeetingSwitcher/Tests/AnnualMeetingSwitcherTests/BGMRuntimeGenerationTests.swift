import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMRuntimeGenerationTests: XCTestCase {
    func testStalePrepareBGMEffectIsIgnored() {
        assertStaleBGMEffectIgnored(.prepareBGM(bgmItem(), generation: 4))
    }

    func testStalePlayBGMEffectIsIgnored() {
        assertStaleBGMEffectIgnored(.playBGM(generation: 4))
    }

    func testStalePauseBGMEffectIsIgnored() {
        assertStaleBGMEffectIgnored(.pauseBGM(generation: 4))
    }

    func testStaleStopBGMEffectIsIgnored() {
        assertStaleBGMEffectIgnored(.stopBGM(fade: 0.5, generation: 4))
    }

    func testStaleSetBGMVolumeEffectIsIgnored() {
        assertStaleBGMEffectIgnored(.setBGMVolume(0.4, fade: 0.2, generation: 4))
    }

    func testStaleStartBGMTimerEffectIsIgnored() {
        assertStaleBGMTimerEffectIgnored(.startBGMTimer(generation: 4))
    }

    func testStaleStopBGMTimerEffectIsIgnored() {
        assertStaleBGMTimerEffectIgnored(.stopBGMTimer(generation: 4))
    }

    func testCurrentGenerationBGMEffectExecutes() {
        let bgm = BGMRuntimeGenerationPlaybackPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, bgm: bgm)
        let state = state(generation: 5)

        runner.run([.playBGM(generation: 5)], currentState: { state }, dispatch: { _ in })

        XCTAssertEqual(bgm.callCount, 1)
    }

    func testRetiredBGMReleaseTaskDoesNotGuardOnCurrentGeneration() throws {
        let source = try sourceText("ViewModel.swift")
        let body = try functionBody(named: "releaseRetiredBGMPlayerAfterFade", in: source)

        XCTAssertFalse(body.contains("runtime.state.bgm.generation"))
        XCTAssertFalse(body.contains("bgmTransitionGeneration == generation"))
    }

    func testRetiredFallbackCleanupDoesNotGuardOnCurrentGeneration() throws {
        let source = try sourceText("ViewModel.swift")
        let body = try functionBody(named: "retireCurrentBGMFallbackPlayerForSwitch", in: source)

        XCTAssertFalse(body.contains("generation: Int"))
        XCTAssertFalse(body.contains("runtime.state.bgm.generation == generation"))
        XCTAssertTrue(body.contains("replaceCurrentItem(with: nil)"))
    }

    func testCurrentBGMFadeTaskCannotOverwriteCurrentVolume() throws {
        let source = try sourceText("ViewModel.swift")
        let playerFadeBody = try functionBody(named: "fadeCurrentBGMPlayerVolume", in: source)
        let fallbackFadeBody = try functionBody(named: "fadeCurrentBGMFallbackVolume", in: source)

        XCTAssertTrue(playerFadeBody.contains("generation: Int"))
        XCTAssertTrue(playerFadeBody.contains("runtime.state.bgm.generation == generation"))
        XCTAssertTrue(fallbackFadeBody.contains("generation: Int"))
        XCTAssertTrue(fallbackFadeBody.contains("runtime.state.bgm.generation == generation"))
    }

    func testRapidBGM_A_B_C_LeavesOnlyCActive() {
        var state = state(generation: 0)
        let first = bgmItem(title: "A")
        let second = bgmItem(title: "B")
        let third = bgmItem(title: "C")
        state.bgm.items = [first, second, third]

        let a = reduce(state, .operatorSelectedBGM(first.id))
        let b = reduce(a.state, .operatorSelectedBGM(second.id))
        let c = reduce(b.state, .operatorSelectedBGM(third.id))

        XCTAssertEqual(c.state.bgm.currentID, third.id)
        XCTAssertEqual(c.state.bgm.generation, 3)
        XCTAssertEqual(c.effects.filter { if case .prepareBGM = $0 { true } else { false } }, [.prepareBGM(third, generation: 3)])
    }

    func testOldBGMObserverCannotAdvanceNewTrack() {
        var state = state(generation: 0)
        let first = bgmItem(title: "A")
        let second = bgmItem(title: "B")
        state.bgm.items = [first, second]
        state.bgm.playMode = .loopAll

        let selectedA = reduce(state, .operatorSelectedBGM(first.id))
        let selectedB = reduce(selectedA.state, .operatorSelectedBGM(second.id))
        let staleFinish = reduce(selectedB.state, .bgmReachedEnd(generation: selectedA.state.bgm.generation))

        XCTAssertEqual(staleFinish.state.bgm.currentID, second.id)
        XCTAssertEqual(staleFinish.effects, [])
    }

    private func assertStaleBGMEffectIgnored(_ effect: LiveRuntimeEffect) {
        let bgm = BGMRuntimeGenerationPlaybackPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, bgm: bgm)
        let state = state(generation: 5)

        runner.run([effect], currentState: { state }, dispatch: { _ in })

        XCTAssertEqual(bgm.callCount, 0)
    }

    private func assertStaleBGMTimerEffectIgnored(_ effect: LiveRuntimeEffect) {
        let timer = BGMRuntimeGenerationTimerPortSpy()
        let runner = LiveRuntimeEffectRunner(recordsOnly: false, bgmTimer: timer)
        let state = state(generation: 5)

        runner.run([effect], currentState: { state }, dispatch: { _ in })

        XCTAssertEqual(timer.callCount, 0)
    }

    private func state(generation: Int) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.bgm.generation = generation
        return state
    }

    private func bgmItem() -> BGMItem {
        BGMItem(title: "Walk-in", url: URL(fileURLWithPath: "/tmp/walk-in.mp3"))
    }

    private func bgmItem(title: String) -> BGMItem {
        BGMItem(title: title, url: URL(fileURLWithPath: "/tmp/\(title).mp3"))
    }

    private func reduce(_ state: LiveRuntimeState, _ action: LiveRuntimeAction) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(
            state: state,
            action: action,
            environment: .productionBGMOwning()
        )
    }

    private func functionBody(named name: String, in source: String) throws -> String {
        guard let start = source.range(of: "func \(name)") ?? source.range(of: "private func \(name)") else {
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
                    return String(source[start.lowerBound...index])
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

private final class BGMRuntimeGenerationPlaybackPortSpy: BGMPlaybackPort {
    private(set) var callCount = 0

    func prepare(item: BGMItem, generation: Int) { callCount += 1 }
    func play(generation: Int) { callCount += 1 }
    func pause(generation: Int) { callCount += 1 }
    func stop(fade: TimeInterval, generation: Int) { callCount += 1 }
    func setVolume(_ volume: Float, fade: TimeInterval, generation: Int) { callCount += 1 }
    func seekToBeginning(generation: Int) { callCount += 1 }
    func seek(toProgress progress: Double, generation: Int) { callCount += 1 }
    func setPlayMode(_ playMode: BGMPlayMode, generation: Int?) { callCount += 1 }
}

private final class BGMRuntimeGenerationTimerPortSpy: BGMTimerPort {
    private(set) var callCount = 0

    func start(generation: Int) { callCount += 1 }
    func stop(generation: Int) { callCount += 1 }
}
