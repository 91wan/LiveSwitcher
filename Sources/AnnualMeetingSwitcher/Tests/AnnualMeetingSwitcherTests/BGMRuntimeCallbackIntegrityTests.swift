import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMRuntimeCallbackIntegrityTests: XCTestCase {
    func testDispatchRuntimeBGMCallbackReturnsFalseWhenNoActiveGeneration() {
        let viewModel = makeViewModel()

        let accepted = viewModel.dispatchRuntimeBGMCallback { .bgmReachedEnd(generation: $0) }

        XCTAssertFalse(accepted)
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "bgmReachedEnd" })
    }

    func testDispatchRuntimeBGMCallbackReturnsFalseWhenItemMismatch() {
        let viewModel = makeViewModel()
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        viewModel.bgmItems = [first, second]
        viewModel.toggleBGM(first)
        let activeGeneration = viewModel.activeRuntimeBGMCallbackGenerationForTesting ?? 0
        viewModel.currentBGMItem = second
        replaceRuntimeBGMState(in: viewModel, current: second, generation: activeGeneration)

        let accepted = viewModel.dispatchRuntimeBGMCallback { .bgmReachedEnd(generation: $0) }

        XCTAssertFalse(accepted)
        XCTAssertEqual(viewModel.currentBGMItem?.id, second.id)
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "bgmReachedEnd" })
    }

    func testDispatchRuntimeBGMCallbackReturnsFalseWhenURLMismatch() {
        let viewModel = makeViewModel()
        let first = bgmItem(title: "First")
        let replacement = BGMItem(title: "First", url: URL(fileURLWithPath: "/tmp/replacement.mp3"), category: first.category)
        viewModel.bgmItems = [first, replacement]
        viewModel.toggleBGM(first)
        let activeGeneration = viewModel.activeRuntimeBGMCallbackGenerationForTesting ?? 0
        viewModel.currentBGMItem = replacement
        replaceRuntimeBGMState(in: viewModel, current: replacement, generation: activeGeneration)

        let accepted = viewModel.dispatchRuntimeBGMCallback { .bgmReachedEnd(generation: $0) }

        XCTAssertFalse(accepted)
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "bgmReachedEnd" })
    }

    func testDispatchRuntimeBGMCallbackReturnsTrueWhenAccepted() {
        let viewModel = makeViewModel()
        let item = bgmItem()
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)
        let activeGeneration = viewModel.activeRuntimeBGMCallbackGenerationForTesting

        let accepted = viewModel.dispatchRuntimeBGMCallback { .bgmReachedEnd(generation: $0) }

        XCTAssertTrue(accepted)
        XCTAssertEqual(activeGeneration, 1)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "bgmReachedEnd" })
    }

    func testStaleBGMFinishCallbackDoesNotAdvanceCurrentTrack() {
        let viewModel = makeViewModel()
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        viewModel.bgmItems = [first, second]
        viewModel.bgmPlayMode = .loopAll
        viewModel.toggleBGM(first)
        let staleGeneration = viewModel.activeRuntimeBGMCallbackGenerationForTesting ?? 0
        viewModel.toggleBGM(second)
        viewModel.seedActiveRuntimeBGMCallbackForTesting(item: first, generation: staleGeneration)

        viewModel.bgmDidFinish()

        XCTAssertEqual(viewModel.runtime.state.bgm.currentID, second.id)
    }

    func testStaleBGMFinishCallbackDoesNotRecordPlaybackState() {
        let viewModel = makeViewModel()
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        viewModel.bgmItems = [first, second]
        viewModel.toggleBGM(first)
        let staleGeneration = viewModel.activeRuntimeBGMCallbackGenerationForTesting ?? 0
        viewModel.toggleBGM(second)
        viewModel.seedActiveRuntimeBGMCallbackForTesting(item: first, generation: staleGeneration)
        let previousCount = viewModel.supportEvents.filter { $0.kind == .bgmPlaybackChanged }.count

        viewModel.bgmDidFinish()

        XCTAssertEqual(viewModel.supportEvents.filter { $0.kind == .bgmPlaybackChanged }.count, previousCount)
    }

    func testStaleBGMFailureCallbackDoesNotStopCurrentTrack() {
        let viewModel = makeViewModel()
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        viewModel.bgmItems = [first, second]
        viewModel.toggleBGM(first)
        let staleGeneration = viewModel.activeRuntimeBGMCallbackGenerationForTesting ?? 0
        viewModel.toggleBGM(second)
        viewModel.seedActiveRuntimeBGMCallbackForTesting(item: first, generation: staleGeneration)

        viewModel.bgmDidFail()

        XCTAssertEqual(viewModel.runtime.state.bgm.currentID, second.id)
        XCTAssertTrue(viewModel.runtime.state.bgm.isPlaying)
    }

    func testStaleBGMFailureCallbackDoesNotRecordSupportEvent() {
        let viewModel = makeViewModel()
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        viewModel.bgmItems = [first, second]
        viewModel.toggleBGM(first)
        let staleGeneration = viewModel.activeRuntimeBGMCallbackGenerationForTesting ?? 0
        viewModel.toggleBGM(second)
        viewModel.seedActiveRuntimeBGMCallbackForTesting(item: first, generation: staleGeneration)

        viewModel.bgmDidFail()

        XCTAssertFalse(viewModel.supportEvents.contains { $0.kind == .bgmPlaybackFailed })
    }

    func testAcceptedBGMFailureCallbackRecordsSupportEvent() {
        let viewModel = makeViewModel()
        let item = bgmItem()
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)

        viewModel.bgmDidFail()

        XCTAssertTrue(viewModel.supportEvents.contains { $0.kind == .bgmPlaybackFailed })
    }

    func testBGMPrepareSetsActiveCallbackIdentity() {
        let viewModel = makeViewModel()
        let item = bgmItem()
        viewModel.bgmItems = [item]

        viewModel.toggleBGM(item)

        XCTAssertEqual(viewModel.activeRuntimeBGMCallbackGenerationForTesting, 1)
        XCTAssertEqual(viewModel.activeRuntimeBGMCallbackItemIDForTesting, item.id)
        XCTAssertEqual(viewModel.activeRuntimeBGMCallbackURLForTesting, item.url)
    }

    func testBGMStopClearsActiveCallbackIdentity() {
        let viewModel = makeViewModel()
        let item = bgmItem()
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)

        viewModel.toggleBGM(item)

        XCTAssertNil(viewModel.activeRuntimeBGMCallbackGenerationForTesting)
        XCTAssertNil(viewModel.activeRuntimeBGMCallbackItemIDForTesting)
        XCTAssertNil(viewModel.activeRuntimeBGMCallbackURLForTesting)
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "BGMRuntimeCallbackIntegrityTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
    }

    private func bgmItem(title: String = "Walk-in") -> BGMItem {
        BGMItem(title: title, url: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).mp3"))
    }

    private func replaceRuntimeBGMState(in viewModel: SwitcherViewModel, current item: BGMItem, generation: Int) {
        var state = viewModel.runtime.state
        state.bgm.items = viewModel.bgmItems
        state.bgm.currentID = item.id
        state.bgm.generation = generation
        viewModel.runtime.replaceStateForFacadeSync(state, clearActionLog: true)
    }
}
