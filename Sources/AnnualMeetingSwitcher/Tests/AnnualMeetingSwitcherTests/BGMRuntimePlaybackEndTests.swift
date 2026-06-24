import XCTest
@testable import LiveSwitcher

final class BGMRuntimePlaybackEndTests: XCTestCase {
    func testLoopOneRestartsSameBGM() {
        let first = item("First")
        let mutation = reduce(state(items: [first], current: first, playMode: .loopOne), .bgmReachedEnd(generation: 4))

        XCTAssertEqual(mutation.state.bgm.currentID, first.id)
        XCTAssertTrue(mutation.effects.contains(.prepareBGM(first, generation: 5)))
        XCTAssertTrue(mutation.effects.contains(.playBGM(generation: 5)))
    }

    func testLoopAllAdvancesToNextBGM() {
        let first = item("First")
        let second = item("Second")
        let mutation = reduce(state(items: [first, second], current: first, playMode: .loopAll), .bgmReachedEnd(generation: 4))

        XCTAssertEqual(mutation.state.bgm.currentID, second.id)
        XCTAssertTrue(mutation.effects.contains(.prepareBGM(second, generation: 5)))
    }

    func testLoopAllWrapsToFirstBGM() {
        let first = item("First")
        let second = item("Second")
        let mutation = reduce(state(items: [first, second], current: second, playMode: .loopAll), .bgmReachedEnd(generation: 4))

        XCTAssertEqual(mutation.state.bgm.currentID, first.id)
        XCTAssertTrue(mutation.effects.contains(.prepareBGM(first, generation: 5)))
    }

    func testSequentialAdvancesToNextBGM() {
        let first = item("First")
        let second = item("Second")
        let mutation = reduce(state(items: [first, second], current: first, playMode: .sequential), .bgmReachedEnd(generation: 4))

        XCTAssertEqual(mutation.state.bgm.currentID, second.id)
        XCTAssertTrue(mutation.effects.contains(.prepareBGM(second, generation: 5)))
    }

    func testSequentialStopsAtLastBGM() {
        let first = item("First")
        let second = item("Second")
        let mutation = reduce(state(items: [first, second], current: second, playMode: .sequential), .bgmReachedEnd(generation: 4))

        XCTAssertEqual(mutation.state.bgm.currentID, second.id)
        XCTAssertFalse(mutation.state.bgm.isPlaying)
        XCTAssertTrue(mutation.effects.contains(.stopBGM(fade: 0, generation: 5)))
    }

    func testBGMReachedEndWithMissingCurrentStopsSafely() {
        var state = LiveRuntimeState()
        state.bgm.generation = 4
        state.bgm.phase = .playing

        let mutation = reduce(state, .bgmReachedEnd(generation: 4))

        XCTAssertFalse(mutation.state.bgm.isPlaying)
        XCTAssertTrue(mutation.effects.contains(.stopBGM(fade: 0, generation: 5)))
    }

    func testBGMReachedEndWithEmptyCategoryStopsSafely() {
        let current = item("Detached")
        var state = self.state(items: [], current: current, playMode: .loopAll)
        state.bgm.currentID = current.id

        let mutation = reduce(state, .bgmReachedEnd(generation: 4))

        XCTAssertFalse(mutation.state.bgm.isPlaying)
        XCTAssertTrue(mutation.effects.contains(.stopBGM(fade: 0, generation: 5)))
    }

    func testBGMReachedEndDuringPanicDoesNotStartAudibleNextTrack() {
        let first = item("First")
        let second = item("Second")
        var state = self.state(items: [first, second], current: first, playMode: .loopAll)
        state.panic.isActive = true

        let mutation = reduce(state, .bgmReachedEnd(generation: 4))

        XCTAssertEqual(mutation.state.bgm.currentID, first.id)
        XCTAssertFalse(mutation.state.bgm.isPlaying)
        XCTAssertFalse(mutation.effects.contains(.prepareBGM(second, generation: 5)))
        XCTAssertTrue(mutation.effects.contains(.stopBGM(fade: 0, generation: 5)))
    }

    func testStaleBGMReachedEndIgnored() {
        let first = item("First")
        let mutation = reduce(state(items: [first], current: first, playMode: .loopOne), .bgmReachedEnd(generation: 3))

        XCTAssertEqual(mutation.state.bgm.currentID, first.id)
        XCTAssertEqual(mutation.state.bgm.generation, 4)
        XCTAssertEqual(mutation.effects, [])
    }

    private func state(items: [BGMItem], current: BGMItem, playMode: BGMPlayMode) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.bgm.items = items
        state.bgm.currentID = current.id
        state.bgm.generation = 4
        state.bgm.phase = .playing
        state.bgm.playMode = playMode
        return state
    }

    private func reduce(_ state: LiveRuntimeState, _ action: LiveRuntimeAction) -> LiveRuntimeMutation {
        LiveRuntimeReducer.reduce(state: state, action: action, environment: .productionBGMOwning())
    }

    private func item(_ title: String) -> BGMItem {
        BGMItem(title: title, url: URL(fileURLWithPath: "/tmp/\(title).mp3"), category: .warmUp)
    }
}
