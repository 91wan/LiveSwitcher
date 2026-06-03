import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMRuntimeCallbackIntegrityTests: XCTestCase {
    func testBGMCallbackIgnoredWhenNoActiveGeneration() {
        let viewModel = makeViewModel()

        viewModel.dispatchRuntimeBGMCallback { .bgmReachedEnd(generation: $0) }

        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "bgmReachedEnd" })
    }

    func testBGMCallbackIgnoredWhenCurrentItemDoesNotMatchActiveItem() {
        let viewModel = makeViewModel()
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        viewModel.bgmItems = [first, second]
        viewModel.toggleBGM(first)
        viewModel.currentBGMItem = second

        viewModel.dispatchRuntimeBGMCallback { .bgmReachedEnd(generation: $0) }

        XCTAssertEqual(viewModel.currentBGMItem?.id, second.id)
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "bgmReachedEnd" })
    }

    func testBGMCallbackIgnoredWhenCurrentURLDoesNotMatchActiveURL() {
        let viewModel = makeViewModel()
        let first = bgmItem(title: "First")
        let replacement = BGMItem(title: "First", url: URL(fileURLWithPath: "/tmp/replacement.mp3"), category: first.category)
        viewModel.bgmItems = [first, replacement]
        viewModel.toggleBGM(first)
        viewModel.currentBGMItem = replacement

        viewModel.dispatchRuntimeBGMCallback { .bgmReachedEnd(generation: $0) }

        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "bgmReachedEnd" })
    }

    func testBGMCallbackUsesActiveGeneration() {
        let viewModel = makeViewModel()
        let item = bgmItem()
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)
        let activeGeneration = viewModel.activeRuntimeBGMCallbackGenerationForTesting

        viewModel.dispatchRuntimeBGMCallback { .bgmReachedEnd(generation: $0) }

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
        viewModel.toggleBGM(second)
        viewModel.currentBGMItem = first

        viewModel.bgmDidFinish()

        XCTAssertEqual(viewModel.runtime.state.bgm.currentID, second.id)
    }

    func testStaleBGMFailureCallbackDoesNotStopCurrentTrack() {
        let viewModel = makeViewModel()
        let first = bgmItem(title: "First")
        let second = bgmItem(title: "Second")
        viewModel.bgmItems = [first, second]
        viewModel.toggleBGM(first)
        viewModel.toggleBGM(second)
        viewModel.currentBGMItem = first

        viewModel.bgmDidFail()

        XCTAssertEqual(viewModel.runtime.state.bgm.currentID, second.id)
        XCTAssertTrue(viewModel.runtime.state.bgm.isPlaying)
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
}
