import XCTest
@testable import LiveSwitcher

final class BGMRuntimeCallbackOwnershipGuardTests: XCTestCase {
    func testBGMPreparedNoopsBeforeBGMOwnership() {
        let state = bgmState()
        let mutation = reduce(state, .bgmPrepared(id: state.bgm.currentID!, generation: 7), bridgeMode: .mediaOwned)

        XCTAssertEqual(mutation.state.bgm, state.bgm)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testBGMPlaybackChangedNoopsBeforeBGMOwnership() {
        let state = bgmState(isPlaying: false)
        let mutation = reduce(state, .bgmPlaybackChanged(isPlaying: true, generation: 7), bridgeMode: .mediaOwned)

        XCTAssertEqual(mutation.state.bgm, state.bgm)
        XCTAssertEqual(mutation.state.audio, state.audio)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testBGMReachedEndNoopsBeforeBGMOwnership() {
        let state = bgmState()
        let mutation = reduce(state, .bgmReachedEnd(generation: 7), bridgeMode: .mediaOwned)

        XCTAssertEqual(mutation.state.bgm, state.bgm)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testBGMFailedNoopsBeforeBGMOwnership() {
        let state = bgmState()
        let mutation = reduce(state, .bgmFailed(reason: "decode", generation: 7), bridgeMode: .mediaOwned)

        XCTAssertEqual(mutation.state.bgm, state.bgm)
        XCTAssertEqual(mutation.state.support, state.support)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testBGMProgressUpdatedNoopsBeforeBGMOwnership() {
        let state = bgmState()
        let mutation = reduce(state, .bgmProgressUpdated(time: 20, duration: 100, generation: 7), bridgeMode: .mediaOwned)

        XCTAssertEqual(mutation.state.bgm, state.bgm)
        XCTAssertTrue(mutation.effects.isEmpty)
    }

    func testBGMPlaybackChangedMutatesWhenBGMOwned() {
        let mutation = reduce(bgmState(isPlaying: false), .bgmPlaybackChanged(isPlaying: true, generation: 7), bridgeMode: .bgmOwned)

        XCTAssertTrue(mutation.state.bgm.isPlaying)
        XCTAssertTrue(mutation.state.audio.routingContext.isBGMPlaying)
        XCTAssertTrue(mutation.effects.contains(.applyAudioRouting(reason: .bgmPlaybackChanged)))
    }

    func testBGMReachedEndMutatesWhenBGMOwned() {
        let state = bgmState()
        let mutation = reduce(state, .bgmReachedEnd(generation: 7), bridgeMode: .bgmOwned)

        XCTAssertFalse(mutation.state.bgm.isPlaying)
        XCTAssertEqual(mutation.state.bgm.generation, 8)
        XCTAssertTrue(mutation.effects.contains(.stopBGMTimer(generation: 8)))
    }

    func testBGMFailedMutatesWhenBGMOwned() {
        let state = bgmState()
        let mutation = reduce(state, .bgmFailed(reason: "decode", generation: 7), bridgeMode: .bgmOwned)

        XCTAssertFalse(mutation.state.bgm.isPlaying)
        XCTAssertEqual(mutation.state.bgm.generation, 8)
        XCTAssertTrue(mutation.effects.contains(.stopBGMTimer(generation: 8)))
    }

    func testBGMProgressUpdatedMutatesWhenBGMOwned() {
        let mutation = reduce(bgmState(), .bgmProgressUpdated(time: 20, duration: 100, generation: 7), bridgeMode: .bgmOwned)

        XCTAssertEqual(mutation.state.bgm.currentTime, 20)
        XCTAssertEqual(mutation.state.bgm.duration, 100)
        XCTAssertEqual(mutation.state.bgm.progress, 0.2, accuracy: 0.0001)
    }

    func testAllBGMCallbackCasesHaveExplicitBGMOwnershipGuard() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeReducer.swift")

        [
            ".bgmPrepared(let id, let generation)",
            ".bgmPlaybackChanged(let isPlaying, let generation)",
            ".bgmReachedEnd(let generation)",
            ".bgmFailed(let reason, let generation)",
            ".bgmProgressUpdated(let time, let duration, let generation)"
        ].forEach { casePattern in
            assertCase(casePattern, in: source, contains: "guard isRuntimeOwned(.bgm, in: bridgeMode) else { break }")
        }
    }

    private func bgmState(isPlaying: Bool = true) -> LiveRuntimeState {
        let item = BGMItem(
            id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
            title: "Walk In",
            url: URL(fileURLWithPath: "/tmp/walk-in.mp3"),
            category: .warmUp
        )
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        state.bgm.currentID = item.id
        state.bgm.isPlaying = isPlaying
        state.bgm.generation = 7
        state.bgm.currentTime = 10
        state.bgm.duration = 50
        state.bgm.progress = 0.2
        state.audio.routingContext.isBGMPlaying = isPlaying
        state.bgm.playMode = .sequential
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
        let endIndex = source.index(range.lowerBound, offsetBy: 420, limitedBy: source.endIndex) ?? source.endIndex
        let body = String(source[range.lowerBound..<endIndex])

        XCTAssertTrue(body.contains(expected), "Missing BGM ownership guard in \(casePattern)", file: file, line: line)
    }
}
