import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeOwnedBGMSnapshotTests: XCTestCase {
    func testBGMOwnedSnapshotPreservesRuntimePlayMode() {
        let item = bgmItem(title: "Runtime")
        let viewModel = makeBGMOwnedViewModel(
            runtimeBGM: bgmState(item: item, playMode: .sequential),
            facadeItems: [item],
            facadePlayMode: .loopAll
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.bgm.playMode, .sequential)
    }

    func testBGMOwnedSnapshotPreservesRuntimeCurrentID() {
        let runtimeItem = bgmItem(title: "Runtime")
        let facadeItem = bgmItem(title: "Facade")
        let viewModel = makeBGMOwnedViewModel(
            runtimeBGM: bgmState(item: runtimeItem),
            facadeItems: [runtimeItem, facadeItem],
            facadeCurrentItem: facadeItem
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.bgm.currentID, runtimeItem.id)
    }

    func testBGMOwnedSnapshotPreservesRuntimeIsPlaying() {
        let item = bgmItem(title: "Runtime")
        let viewModel = makeBGMOwnedViewModel(
            runtimeBGM: bgmState(item: item, isPlaying: true),
            facadeItems: [item],
            facadeIsPlaying: false
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertTrue(viewModel.runtime.state.bgm.isPlaying)
    }

    func testBGMOwnedSnapshotPreservesRuntimeProgress() {
        let item = bgmItem(title: "Runtime")
        let viewModel = makeBGMOwnedViewModel(
            runtimeBGM: bgmState(item: item, progress: 0.65),
            facadeItems: [item],
            facadeProgress: 0.1
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.bgm.progress, 0.65, accuracy: 0.0001)
    }

    func testBGMOwnedSnapshotPreservesRuntimeCurrentTime() {
        let item = bgmItem(title: "Runtime")
        let viewModel = makeBGMOwnedViewModel(
            runtimeBGM: bgmState(item: item, currentTime: 42),
            facadeItems: [item],
            facadeCurrentTime: 2
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.bgm.currentTime, 42, accuracy: 0.0001)
    }

    func testBGMOwnedSnapshotPreservesRuntimeDuration() {
        let item = bgmItem(title: "Runtime")
        let viewModel = makeBGMOwnedViewModel(
            runtimeBGM: bgmState(item: item, duration: 120),
            facadeItems: [item],
            facadeDuration: 10
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(try XCTUnwrap(viewModel.runtime.state.bgm.duration), 120, accuracy: 0.0001)
    }

    func testBGMOwnedSnapshotPreservesRuntimeGeneration() {
        let item = bgmItem(title: "Runtime")
        let viewModel = makeBGMOwnedViewModel(
            runtimeBGM: bgmState(item: item, generation: 9),
            facadeItems: [item]
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.bgm.generation, 9)
    }

    func testBGMOwnedSnapshotDoesNotOverwriteRuntimePlayModeWithStaleFacade() {
        let item = bgmItem(title: "Runtime")
        let viewModel = makeBGMOwnedViewModel(
            runtimeBGM: bgmState(item: item, playMode: .loopOne),
            facadeItems: [item],
            facadePlayMode: .sequential
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.bgm.playMode, .loopOne)
    }

    func testBGMOwnedSnapshotKeepsViewModelLibraryItems() {
        let runtimeItem = bgmItem(title: "Runtime")
        let libraryItem = bgmItem(title: "Library")
        let viewModel = makeBGMOwnedViewModel(
            runtimeBGM: bgmState(item: runtimeItem),
            facadeItems: [libraryItem]
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertTrue(viewModel.runtime.state.bgm.items.contains { $0.id == libraryItem.id })
    }

    func testBGMLibraryStillViewModelOwned() {
        let runtimeItem = bgmItem(title: "Runtime")
        let libraryItem = bgmItem(title: "Library")
        let viewModel = makeBGMOwnedViewModel(
            runtimeBGM: bgmState(item: runtimeItem),
            facadeItems: [libraryItem]
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.bgm.items.map(\.id), [libraryItem.id, runtimeItem.id])
    }

    func testBGMOwnedSnapshotStillAcceptsViewModelLibraryItems() {
        let runtimeItem = bgmItem(title: "Runtime")
        let libraryItem = bgmItem(title: "Library")
        let viewModel = makeBGMOwnedViewModel(
            runtimeBGM: bgmState(item: runtimeItem),
            facadeItems: [libraryItem]
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertTrue(viewModel.runtime.state.bgm.items.contains { $0.id == libraryItem.id })
        XCTAssertEqual(viewModel.runtime.state.bgm.currentID, runtimeItem.id)
    }

    func testBGMOwnedSnapshotKeepsRuntimeCurrentItemWhenMissingFromLibrary() {
        let runtimeItem = bgmItem(title: "Runtime")
        let libraryItem = bgmItem(title: "Library")
        let viewModel = makeBGMOwnedViewModel(
            runtimeBGM: bgmState(item: runtimeItem),
            facadeItems: [libraryItem]
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertTrue(viewModel.runtime.state.bgm.items.contains { $0.id == runtimeItem.id })
        XCTAssertEqual(viewModel.runtime.state.bgm.currentID, runtimeItem.id)
    }

    func testNonBGMOwnedSnapshotUsesFacadePlayMode() {
        let item = bgmItem(title: "Facade")
        let viewModel = makeViewModel(
            bridgeMode: .mediaOwned,
            runtimeBGM: bgmState(item: item, playMode: .loopOne),
            facadeItems: [item],
            facadePlayMode: .sequential
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.bgm.playMode, .sequential)
    }

    func testNonBGMOwnedSnapshotUsesFacadeCurrentBGM() {
        let runtimeItem = bgmItem(title: "Runtime")
        let facadeItem = bgmItem(title: "Facade")
        let viewModel = makeViewModel(
            bridgeMode: .mediaOwned,
            runtimeBGM: bgmState(item: runtimeItem),
            facadeItems: [facadeItem],
            facadeCurrentItem: facadeItem
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.bgm.currentID, facadeItem.id)
    }

    func testNonBGMOwnedSnapshotUsesFacadeProgress() {
        let item = bgmItem(title: "Facade")
        let viewModel = makeViewModel(
            bridgeMode: .mediaOwned,
            runtimeBGM: bgmState(item: item, progress: 0.9, currentTime: 90, duration: 100),
            facadeItems: [item],
            facadeProgress: 0.25,
            facadeCurrentTime: 25,
            facadeDuration: 100
        )

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.bgm.progress, 0.25, accuracy: 0.0001)
        XCTAssertEqual(viewModel.runtime.state.bgm.currentTime, 25, accuracy: 0.0001)
    }

    func testRuntimeSnapshotSourceUsesBGMHelperAndRemovesOldHelperName() throws {
        let source = try repositorySource(
            "Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeSnapshot.swift"
        )

        XCTAssertTrue(source.contains("syncBGMIntoRuntimeSnapshot"))
        XCTAssertFalse(source.contains("syncBGMLibraryIntoRuntimeSnapshot"))
    }

    private func makeBGMOwnedViewModel(
        runtimeBGM: BGMRuntimeState,
        facadeItems: [BGMItem],
        facadeCurrentItem: BGMItem? = nil,
        facadeIsPlaying: Bool = false,
        facadePlayMode: BGMPlayMode = .loopAll,
        facadeProgress: Double = 0,
        facadeCurrentTime: Double = 0,
        facadeDuration: Double? = nil
    ) -> SwitcherViewModel {
        makeViewModel(
            bridgeMode: .bgmOwned,
            runtimeBGM: runtimeBGM,
            facadeItems: facadeItems,
            facadeCurrentItem: facadeCurrentItem,
            facadeIsPlaying: facadeIsPlaying,
            facadePlayMode: facadePlayMode,
            facadeProgress: facadeProgress,
            facadeCurrentTime: facadeCurrentTime,
            facadeDuration: facadeDuration
        )
    }

    private func makeViewModel(
        bridgeMode: LiveRuntimeBridgeMode,
        runtimeBGM: BGMRuntimeState,
        facadeItems: [BGMItem],
        facadeCurrentItem: BGMItem? = nil,
        facadeIsPlaying: Bool = false,
        facadePlayMode: BGMPlayMode = .loopAll,
        facadeProgress: Double = 0,
        facadeCurrentTime: Double = 0,
        facadeDuration: Double? = nil
    ) -> SwitcherViewModel {
        var runtimeState = LiveRuntimeState()
        runtimeState.bgm = runtimeBGM
        let runtime = LiveRuntimeStore(
            initialState: runtimeState,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        viewModel.bgmItems = facadeItems
        viewModel.currentBGMItem = facadeCurrentItem
        viewModel.isBGMPlaying = facadeIsPlaying
        viewModel.bgmPlayMode = facadePlayMode
        viewModel.bgmProgress = facadeProgress
        viewModel.bgmCurrentTime = facadeCurrentTime
        viewModel.bgmDuration = facadeDuration
        return viewModel
    }

    private func bgmState(
        item: BGMItem,
        isPlaying: Bool = false,
        playMode: BGMPlayMode = .loopAll,
        progress: Double = 0,
        currentTime: Double = 0,
        duration: Double? = nil,
        generation: Int = 0
    ) -> BGMRuntimeState {
        var bgm = BGMRuntimeState()
        bgm.items = [item]
        bgm.currentID = item.id
        bgm.isPlaying = isPlaying
        bgm.playMode = playMode
        bgm.progress = progress
        bgm.currentTime = currentTime
        bgm.duration = duration
        bgm.generation = generation
        return bgm
    }

    private func bgmItem(title: String, category: BGMCategory = .warmUp) -> BGMItem {
        BGMItem(
            id: UUID(),
            title: title,
            url: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).mp3"),
            category: category
        )
    }
}
