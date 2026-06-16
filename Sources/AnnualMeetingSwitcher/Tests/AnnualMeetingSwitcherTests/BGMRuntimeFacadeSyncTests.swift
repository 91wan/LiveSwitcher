import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMRuntimeFacadeSyncTests: XCTestCase {
    func testBGMOwnedFacadeSyncPreservesRuntimeCurrentID() {
        let item = bgmItem(title: "Runtime")
        let other = bgmItem(title: "Facade")
        let viewModel = makeViewModel()
        viewModel.bgmItems = [item, other]
        viewModel.currentBGMItem = other
        seedRuntimeBGM(viewModel, item: item)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.bgm.currentID, item.id)
    }

    func testBGMOwnedFacadeSyncPreservesRuntimeIsPlaying() {
        let item = bgmItem(title: "Runtime")
        let viewModel = makeViewModel()
        viewModel.bgmItems = [item]
        viewModel.isBGMPlaying = false
        seedRuntimeBGM(viewModel, item: item, isPlaying: true)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertTrue(viewModel.runtime.state.bgm.isPlaying)
    }

    func testBGMOwnedFacadeSyncPreservesRuntimeProgressAndTime() {
        let item = bgmItem(title: "Runtime")
        let viewModel = makeViewModel()
        viewModel.bgmItems = [item]
        viewModel.bgmProgressStore.update(currentTime: 1, duration: 10)
        seedRuntimeBGM(viewModel, item: item, progress: 0.8, currentTime: 8, duration: 10)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.bgm.progress, 0.8, accuracy: 0.0001)
        XCTAssertEqual(viewModel.runtime.state.bgm.currentTime, 8, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(viewModel.runtime.state.bgm.duration), 10, accuracy: 0.0001)
    }

    func testBGMOwnedFacadeSyncPreservesRuntimeGeneration() {
        let item = bgmItem(title: "Runtime")
        let viewModel = makeViewModel()
        viewModel.bgmItems = [item]
        seedRuntimeBGM(viewModel, item: item, generation: 9)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.bgm.generation, 9)
    }

    func testBGMOwnedFacadeSyncStillUpdatesLibraryItems() {
        let item = bgmItem(title: "Library")
        let runtimeItem = bgmItem(title: "Runtime")
        let viewModel = makeViewModel()
        viewModel.bgmItems = [item]
        viewModel.bgmPlayMode = .sequential
        seedRuntimeBGM(viewModel, item: runtimeItem, playMode: .loopAll)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.bgm.items.map(\.id), [item.id, runtimeItem.id])
        XCTAssertEqual(viewModel.runtime.state.bgm.playMode, .loopAll)
    }

    func testBGMFacadeSyncProjectsPlayMode() {
        let item = bgmItem(title: "Runtime")
        let viewModel = makeViewModel()
        viewModel.bgmPlayMode = .loopAll
        seedRuntimeBGM(viewModel, item: item, playMode: .sequential)

        viewModel.syncBGMFacadeFromRuntime()

        XCTAssertEqual(viewModel.bgmPlayMode, .sequential)
    }

    func testOperatorSelectedBGMSyncsFacadeCurrentItemFromRuntime() {
        let item = bgmItem(title: "Select")
        let viewModel = makeViewModel()
        viewModel.bgmItems = [item]

        viewModel.toggleBGM(item)

        XCTAssertEqual(viewModel.currentBGMItem?.id, item.id)
        XCTAssertTrue(viewModel.isBGMPlaying)
    }

    func testBGMProgressCallbackSyncsFacadeProgressFromRuntime() {
        let item = bgmItem(title: "Progress")
        let viewModel = makeViewModel()
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)

        viewModel.dispatchRuntimeBGMProgressCallback(time: 6, duration: 10)

        XCTAssertEqual(viewModel.bgmProgress, 0.6, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmCurrentTime, 6, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(viewModel.bgmDuration), 10, accuracy: 0.0001)
    }

    func testBGMFailureSyncsFacadeStoppedStateFromRuntime() {
        let item = bgmItem(title: "Failure")
        let viewModel = makeViewModel()
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)

        viewModel.bgmDidFail()

        XCTAssertFalse(viewModel.isBGMPlaying)
    }

    private func seedRuntimeBGM(
        _ viewModel: SwitcherViewModel,
        item: BGMItem,
        isPlaying: Bool = true,
        progress: Double = 0,
        currentTime: Double = 0,
        duration: Double? = nil,
        playMode: BGMPlayMode = .loopAll,
        generation: Int = 3
    ) {
        var state = viewModel.runtime.state
        state.bgm.items = [item]
        state.bgm.currentID = item.id
        state.bgm.isPlaying = isPlaying
        state.bgm.playMode = playMode
        state.bgm.progress = progress
        state.bgm.currentTime = currentTime
        state.bgm.duration = duration
        state.bgm.generation = generation
        viewModel.runtime.replaceStateForFacadeSync(state)
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "BGMRuntimeFacadeSyncTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
    }

    private func bgmItem(title: String) -> BGMItem {
        BGMItem(title: title, url: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).mp3"))
    }
}
