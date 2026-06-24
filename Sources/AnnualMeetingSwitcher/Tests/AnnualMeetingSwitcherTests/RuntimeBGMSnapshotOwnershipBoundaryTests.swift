import XCTest
@testable import LiveSwitcher

@MainActor
final class RuntimeBGMSnapshotOwnershipBoundaryTests: XCTestCase {
    func testBGMOwnedReachedEndUsesRuntimeSequentialDespiteStaleFacadeLoopAll() {
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        let viewModel = makeBGMOwnedViewModel(
            runtimeBGM: bgmState(
                items: [first, second],
                current: second,
                playMode: .sequential,
                generation: 4
            ),
            facadeItems: [first, second],
            facadeCurrentItem: second,
            facadePlayMode: .loopAll
        )

        let accepted = viewModel.dispatchRuntimeBGMCallback { .bgmReachedEnd(generation: $0) }

        XCTAssertTrue(accepted)
        XCTAssertEqual(viewModel.runtime.state.bgm.playMode, .sequential)
        XCTAssertEqual(viewModel.runtime.state.bgm.currentID, second.id)
        XCTAssertFalse(viewModel.runtime.state.bgm.isPlaying)
        XCTAssertTrue(viewModel.runtime.recordedEffects.contains(.stopBGM(fade: 0, generation: 5)))
        XCTAssertFalse(viewModel.runtime.recordedEffects.contains { effect in
            if case .prepareBGM(let item, _) = effect {
                return item.id == first.id
            }
            return false
        })
    }

    func testBGMOwnedReachedEndUsesRuntimeLoopOneDespiteStaleFacadeSequential() {
        let item = bgmItem(title: "Loop One")
        let viewModel = makeBGMOwnedViewModel(
            runtimeBGM: bgmState(
                items: [item],
                current: item,
                playMode: .loopOne,
                generation: 4
            ),
            facadeItems: [item],
            facadePlayMode: .sequential
        )

        let accepted = viewModel.dispatchRuntimeBGMCallback { .bgmReachedEnd(generation: $0) }

        XCTAssertTrue(accepted)
        XCTAssertEqual(viewModel.runtime.state.bgm.playMode, .loopOne)
        XCTAssertEqual(viewModel.runtime.state.bgm.currentID, item.id)
        XCTAssertTrue(viewModel.runtime.state.bgm.isPlaying)
        XCTAssertTrue(viewModel.runtime.recordedEffects.contains(.prepareBGM(item, generation: 5)))
        XCTAssertTrue(viewModel.runtime.recordedEffects.contains(.playBGM(generation: 5)))
    }

    func testBGMOwnedDispatchDoesNotOverwriteRuntimePlayModeBeforeReachedEnd() {
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        let viewModel = makeBGMOwnedViewModel(
            runtimeBGM: bgmState(
                items: [first, second],
                current: second,
                playMode: .sequential,
                generation: 9
            ),
            facadeItems: [first, second],
            facadePlayMode: .loopAll
        )

        let accepted = viewModel.dispatchRuntimeBGMCallback { .bgmReachedEnd(generation: $0) }

        XCTAssertTrue(accepted)
        XCTAssertEqual(viewModel.runtime.state.bgm.playMode, .sequential)
        XCTAssertFalse(viewModel.runtime.state.bgm.isPlaying)
        XCTAssertEqual(viewModel.runtime.state.bgm.generation, 10)
    }

    private func makeBGMOwnedViewModel(
        runtimeBGM: BGMRuntimeState,
        facadeItems: [BGMItem],
        facadeCurrentItem: BGMItem? = nil,
        facadePlayMode: BGMPlayMode
    ) -> SwitcherViewModel {
        var runtimeState = LiveRuntimeState()
        runtimeState.bgm = runtimeBGM
        let runtime = LiveRuntimeStore(
            initialState: runtimeState,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: .bgmOwned)
        )
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: runtime
        )
        viewModel.bgmItems = facadeItems
        viewModel.currentBGMItem = facadeCurrentItem
        viewModel.bgmPlayMode = facadePlayMode
        if let currentItem = runtimeBGM.currentItem {
            viewModel.setActiveRuntimeBGMCallbackIdentity(item: currentItem, generation: runtimeBGM.generation)
            viewModel.currentBGMItem = currentItem
        }
        return viewModel
    }

    private func bgmState(
        items: [BGMItem],
        current: BGMItem,
        playMode: BGMPlayMode,
        generation: Int
    ) -> BGMRuntimeState {
        var bgm = BGMRuntimeState()
        bgm.items = items
        bgm.currentID = current.id
        bgm.phase = .playing
        bgm.playMode = playMode
        bgm.generation = generation
        return bgm
    }

    private func bgmItem(title: String) -> BGMItem {
        BGMItem(
            id: UUID(),
            title: title,
            url: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).mp3"),
            category: .warmUp
        )
    }
}
