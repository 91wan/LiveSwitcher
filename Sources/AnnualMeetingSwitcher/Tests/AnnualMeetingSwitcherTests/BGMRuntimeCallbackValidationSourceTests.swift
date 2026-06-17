import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMRuntimeCallbackValidationSourceTests: XCTestCase {
    func testBGMCallbackValidationUsesRuntimeCurrentItemWhenBGMOwned() {
        let runtimeItem = bgmItem(title: "Runtime")
        let staleFacade = bgmItem(title: "Facade")
        let viewModel = makeViewModel(
            bridgeMode: .bgmOwned,
            initialState: runtimeState(current: runtimeItem, generation: 8)
        )
        viewModel.bgmItems = [runtimeItem, staleFacade]
        viewModel.currentBGMItem = staleFacade
        viewModel.seedActiveRuntimeBGMCallbackForTesting(item: runtimeItem, generation: 8)

        let accepted = viewModel.dispatchRuntimeBGMCallback { .bgmReachedEnd(generation: $0) }

        XCTAssertTrue(accepted)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "bgmReachedEnd" })
    }

    func testBGMCallbackValidationRejectsWhenRuntimeCurrentItemDiffersEvenIfFacadeMatches() {
        let staleCallbackItem = bgmItem(title: "Stale Callback")
        let runtimeItem = bgmItem(title: "Runtime")
        let viewModel = makeViewModel(
            bridgeMode: .bgmOwned,
            initialState: runtimeState(current: runtimeItem, generation: 8)
        )
        viewModel.bgmItems = [staleCallbackItem, runtimeItem]
        viewModel.currentBGMItem = staleCallbackItem
        viewModel.seedActiveRuntimeBGMCallbackForTesting(item: staleCallbackItem, generation: 8)

        let accepted = viewModel.dispatchRuntimeBGMCallback { .bgmReachedEnd(generation: $0) }

        XCTAssertFalse(accepted)
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "bgmReachedEnd" })
    }

    func testBGMCallbackValidationAcceptsWhenRuntimeCurrentItemMatchesEvenIfFacadeIsNil() {
        let runtimeItem = bgmItem(title: "Runtime")
        let viewModel = makeViewModel(
            bridgeMode: .bgmOwned,
            initialState: runtimeState(current: runtimeItem, generation: 8)
        )
        viewModel.bgmItems = [runtimeItem]
        viewModel.currentBGMItem = nil
        viewModel.seedActiveRuntimeBGMCallbackForTesting(item: runtimeItem, generation: 8)

        let accepted = viewModel.dispatchRuntimeBGMCallback {
            .bgmPlaybackChanged(isPlaying: false, generation: $0)
        }

        XCTAssertTrue(accepted)
        XCTAssertFalse(viewModel.runtime.state.bgm.isPlaying)
    }

    func testBGMCallbackValidationRejectsWhenRuntimeCurrentItemURLDiffers() {
        let callbackItem = bgmItem(title: "Callback")
        let runtimeItem = BGMItem(title: "Callback", url: temporaryURL(ext: "mp3"), category: callbackItem.category)
        let viewModel = makeViewModel(
            bridgeMode: .bgmOwned,
            initialState: runtimeState(current: runtimeItem, generation: 8)
        )
        viewModel.bgmItems = [callbackItem, runtimeItem]
        viewModel.currentBGMItem = callbackItem
        viewModel.seedActiveRuntimeBGMCallbackForTesting(item: callbackItem, generation: 8)

        let accepted = viewModel.dispatchRuntimeBGMCallback { .bgmReachedEnd(generation: $0) }

        XCTAssertFalse(accepted)
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "bgmReachedEnd" })
    }

    func testBGMCallbackValidationUsesFacadeCurrentItemBeforeBGMOwnership() {
        let facadeItem = bgmItem(title: "Facade")
        let runtimeItem = bgmItem(title: "Runtime")
        let viewModel = makeViewModel(
            bridgeMode: .mediaOwned,
            initialState: runtimeState(current: runtimeItem, generation: 8)
        )
        viewModel.bgmItems = [facadeItem, runtimeItem]
        viewModel.currentBGMItem = facadeItem
        viewModel.seedActiveRuntimeBGMCallbackForTesting(item: facadeItem, generation: 8)

        let accepted = viewModel.dispatchRuntimeBGMCallback { .bgmReachedEnd(generation: $0) }

        XCTAssertTrue(accepted)
    }

    func testBGMCallbackValidationRequiresRuntimeGenerationWhenBGMOwned() {
        let runtimeItem = bgmItem(title: "Runtime")
        let viewModel = makeViewModel(
            bridgeMode: .bgmOwned,
            initialState: runtimeState(current: runtimeItem, generation: 8)
        )
        viewModel.bgmItems = [runtimeItem]
        viewModel.currentBGMItem = runtimeItem
        viewModel.seedActiveRuntimeBGMCallbackForTesting(item: runtimeItem, generation: 8)

        let accepted = viewModel.dispatchRuntimeBGMCallback {
            .bgmProgressUpdated(time: 12, duration: 24, generation: $0)
        }

        XCTAssertTrue(accepted)
        XCTAssertEqual(viewModel.runtime.state.bgm.currentTime, 12, accuracy: 0.0001)
    }

    func testBGMCallbackValidationRejectsStaleRuntimeBGMGeneration() {
        let runtimeItem = bgmItem(title: "Runtime")
        let viewModel = makeViewModel(
            bridgeMode: .bgmOwned,
            initialState: runtimeState(current: runtimeItem, generation: 8)
        )
        viewModel.bgmItems = [runtimeItem]
        viewModel.currentBGMItem = runtimeItem
        viewModel.seedActiveRuntimeBGMCallbackForTesting(item: runtimeItem, generation: 7)

        let accepted = viewModel.dispatchRuntimeBGMCallback { .bgmReachedEnd(generation: $0) }

        XCTAssertFalse(accepted)
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "bgmReachedEnd" })
    }

    func testBGMPlaybackChangedRejectedWhenRuntimeCurrentBGMChangedButFacadeStillOld() {
        let staleItem = bgmItem(title: "Stale")
        let runtimeItem = bgmItem(title: "Runtime")
        let viewModel = makeViewModel(
            bridgeMode: .bgmOwned,
            initialState: runtimeState(current: runtimeItem, generation: 8)
        )
        viewModel.bgmItems = [staleItem, runtimeItem]
        viewModel.currentBGMItem = staleItem
        viewModel.seedActiveRuntimeBGMCallbackForTesting(item: staleItem, generation: 8)

        let accepted = viewModel.dispatchRuntimeBGMCallback {
            .bgmPlaybackChanged(isPlaying: false, generation: $0)
        }

        XCTAssertFalse(accepted)
        XCTAssertTrue(viewModel.runtime.state.bgm.isPlaying)
    }

    func testBGMProgressRejectedWhenRuntimeBGMGenerationChanged() {
        let runtimeItem = bgmItem(title: "Runtime")
        let viewModel = makeViewModel(
            bridgeMode: .bgmOwned,
            initialState: runtimeState(current: runtimeItem, generation: 8)
        )
        viewModel.bgmItems = [runtimeItem]
        viewModel.currentBGMItem = runtimeItem
        viewModel.seedActiveRuntimeBGMCallbackForTesting(item: runtimeItem, generation: 7)

        let accepted = viewModel.dispatchRuntimeBGMCallback {
            .bgmProgressUpdated(time: 12, duration: 24, generation: $0)
        }

        XCTAssertFalse(accepted)
        XCTAssertEqual(viewModel.runtime.state.bgm.currentTime, 0, accuracy: 0.0001)
    }

    func testBGMReachedEndAcceptedWhenRuntimeCurrentBGMMatchesAndFacadeStaleNil() {
        let runtimeItem = bgmItem(title: "Runtime")
        let viewModel = makeViewModel(
            bridgeMode: .bgmOwned,
            initialState: runtimeState(current: runtimeItem, generation: 8)
        )
        viewModel.bgmItems = [runtimeItem]
        viewModel.currentBGMItem = nil
        viewModel.seedActiveRuntimeBGMCallbackForTesting(item: runtimeItem, generation: 8)

        let accepted = viewModel.dispatchRuntimeBGMCallback { .bgmReachedEnd(generation: $0) }

        XCTAssertTrue(accepted)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "bgmReachedEnd" })
    }

    func testDispatchRuntimeBGMCallbackStillSyncsBGMFacadeAfterAcceptedCallback() {
        let runtimeItem = bgmItem(title: "Runtime")
        let viewModel = makeViewModel(
            bridgeMode: .bgmOwned,
            initialState: runtimeState(current: runtimeItem, generation: 8)
        )
        viewModel.bgmItems = [runtimeItem]
        viewModel.currentBGMItem = nil
        viewModel.seedActiveRuntimeBGMCallbackForTesting(item: runtimeItem, generation: 8)

        let accepted = viewModel.dispatchRuntimeBGMCallback {
            .bgmPlaybackChanged(isPlaying: false, generation: $0)
        }

        XCTAssertTrue(accepted)
        XCTAssertEqual(viewModel.currentBGMItem?.id, runtimeItem.id)
        XCTAssertFalse(viewModel.isBGMPlaying)
    }

    func testBGMCallbackValidationSourceUsesRuntimeBackedHelpers() throws {
        let source = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "validatedRuntimeBGMCallbackGeneration"))

        XCTAssertTrue(source.contains("runtimeBackedCurrentBGMItemForCallbackValidation"))
        XCTAssertTrue(source.contains("runtimeBackedBGMGenerationForCallbackValidation"))
        XCTAssertFalse(body.contains("currentBGMItem?.id =="))
        XCTAssertFalse(body.contains("currentBGMItem?.url =="))
        XCTAssertTrue(body.contains("currentBGM.id == activeRuntimeBGMItemIDForCallbacks"))
        XCTAssertTrue(body.contains("currentBGM.url == activeRuntimeBGMURLForCallbacks"))
    }

    private func makeViewModel(
        bridgeMode: LiveRuntimeBridgeMode,
        initialState: LiveRuntimeState
    ) -> SwitcherViewModel {
        SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            runtime: LiveRuntimeStore(
                initialState: initialState,
                environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
            )
        )
    }

    private func runtimeState(current item: BGMItem, generation: Int) -> LiveRuntimeState {
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        state.bgm.currentID = item.id
        state.bgm.generation = generation
        state.bgm.isPlaying = true
        return state
    }

    private func bgmItem(title: String) -> BGMItem {
        BGMItem(title: title, url: temporaryURL(ext: "mp3"))
    }

    private func temporaryURL(ext: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try? Data("fixture".utf8).write(to: url)
        return url
    }
}
