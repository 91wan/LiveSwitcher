import XCTest
@testable import LiveSwitcher

@MainActor
final class PersistentStateRuntimeLoadBGMTests: XCTestCase {
    func testRecordingOnlyPersistentLoadMirrorsFacadeBGMPlayModeIntoRuntimeShadow() {
        let viewModel = persistentRuntimeLoadMakeViewModel(bridgeMode: .recordingOnly)

        viewModel.applyPersistentState(SwitcherPersistentState(bgmPlayMode: .sequential))

        XCTAssertEqual(viewModel.runtime.state.bgm.playMode, .sequential)
    }

    func testPersistentHydrationDoesNotResetBGMPlaybackFields() {
        let item = BGMItem(title: "Runtime BGM", url: URL(fileURLWithPath: "/tmp/runtime-bgm.mp3"))
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        state.bgm.currentID = item.id
        state.bgm.phase = .playing
        state.bgm.progress = 0.5
        state.bgm.generation = 8
        let viewModel = persistentRuntimeLoadMakeViewModel(runtimeState: state, bridgeMode: .panicOwned)

        viewModel.applyPersistentState(SwitcherPersistentState(bgmPlayMode: .loopOne))

        XCTAssertEqual(viewModel.runtime.state.bgm.currentID, item.id)
        XCTAssertTrue(viewModel.runtime.state.bgm.isPlaying)
        XCTAssertEqual(viewModel.runtime.state.bgm.progress, 0.5)
        XCTAssertEqual(viewModel.runtime.state.bgm.generation, 8)
    }
}
