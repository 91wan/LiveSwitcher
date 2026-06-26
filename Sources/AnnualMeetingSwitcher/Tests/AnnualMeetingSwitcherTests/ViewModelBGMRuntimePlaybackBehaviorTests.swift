import AVFoundation
import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelBGMRuntimePlaybackBehaviorTests: XCTestCase {
    func testPrepareRuntimeBGMStillSetsCallbackIdentity() {
        let viewModel = makeViewModel()
        let item = bgmItem()
        viewModel.bgmItems = [item]

        viewModel.toggleBGM(item)

        XCTAssertEqual(viewModel.activeRuntimeBGMCallbackGenerationForTesting, 1)
        XCTAssertEqual(viewModel.activeRuntimeBGMCallbackItemIDForTesting, item.id)
        XCTAssertEqual(viewModel.activeRuntimeBGMCallbackURLForTesting, item.url)
    }

    func testPlayRuntimeBGMStillStartsFromZeroVolumeAndFadesIn() {
        let viewModel = makeViewModel()
        let item = bgmItem()
        viewModel.bgmItems = [item]
        viewModel.liveAudioFadeDuration = 1.25

        viewModel.toggleBGM(item)

        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertEqual(viewModel.bgmFallbackPlayer.volume, 0, accuracy: 0.0001)
        XCTAssertNotNil(viewModel.cleanupBag.bgmFallbackVolumeFadeTask)
        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.bgmFadeDuration, viewModel.liveAudioFadeDuration)
    }

    func testStopRuntimeBGMStillFadesOutWithConfiguredDuration() {
        let viewModel = makeViewModel()
        let item = bgmItem()
        viewModel.bgmItems = [item]
        viewModel.liveAudioFadeDuration = 1.25
        viewModel.toggleBGM(item)

        viewModel.toggleBGM(item)

        XCTAssertEqual(viewModel.lastAudioRoutingTransition?.bgmFadeDuration, 1.25)
    }

    func testPauseTogglePreservesCallbackIdentityForResume() {
        let viewModel = makeViewModel()
        let item = bgmItem()
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)

        viewModel.toggleBGM(item)

        XCTAssertEqual(viewModel.activeRuntimeBGMCallbackGenerationForTesting, 1)
        XCTAssertEqual(viewModel.activeRuntimeBGMCallbackItemIDForTesting, item.id)
        XCTAssertEqual(viewModel.activeRuntimeBGMCallbackURLForTesting, item.url)
    }

    func testExplicitStopRuntimeBGMStillClearsCallbackIdentity() {
        let viewModel = makeViewModel()
        let item = bgmItem()
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)

        viewModel.dispatchRuntimeFacadeAction(.operatorStoppedBGM)

        XCTAssertNil(viewModel.activeRuntimeBGMCallbackGenerationForTesting)
        XCTAssertNil(viewModel.activeRuntimeBGMCallbackItemIDForTesting)
        XCTAssertNil(viewModel.activeRuntimeBGMCallbackURLForTesting)
    }

    func testSeekRuntimeBGMToBeginningStillUpdatesProgressStore() {
        let viewModel = makeViewModel()
        let item = bgmItem()
        replaceRuntimeBGMState(
            in: viewModel,
            item: item,
            phase: .selected,
            generation: 5,
            effectiveBGM: 0
        )

        viewModel.bgmProgressStore.update(currentTime: 4, duration: 10)
        viewModel.seekRuntimeBGMToBeginning(generation: 5)

        XCTAssertEqual(viewModel.bgmProgress, 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmCurrentTime, 0, accuracy: 0.0001)
    }

    func testAudiblePlayingSeekRuntimeBGMToBeginningUsesReturnToStartSmoothingTask() {
        let viewModel = makeViewModel()
        let item = bgmItem()
        replaceRuntimeBGMState(
            in: viewModel,
            item: item,
            phase: .playing,
            generation: 5,
            effectiveBGM: 0.35
        )
        viewModel.bgmFallbackPlayer.volume = 0.35

        viewModel.seekRuntimeBGMToBeginning(generation: 5)

        XCTAssertNotNil(viewModel.cleanupBag.bgmReturnToStartTask)
        XCTAssertNil(viewModel.cleanupBag.bgmFallbackVolumeFadeTask)
    }

    func testMutedPlayingSeekRuntimeBGMToBeginningSeeksImmediatelyWithoutSmoothingTask() {
        let viewModel = makeViewModel()
        let item = bgmItem()
        replaceRuntimeBGMState(
            in: viewModel,
            item: item,
            phase: .playing,
            generation: 5,
            effectiveBGM: 0.35,
            isBGMMuted: true
        )
        viewModel.bgmProgressStore.update(currentTime: 4, duration: 10)

        viewModel.seekRuntimeBGMToBeginning(generation: 5)

        XCTAssertNil(viewModel.cleanupBag.bgmReturnToStartTask)
        XCTAssertEqual(viewModel.bgmProgress, 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmCurrentTime, 0, accuracy: 0.0001)
    }

    func testSeekRuntimeBGMToBeginningSourceUsesSmoothingPolicyAndGenerationGuards() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+BGMRuntimePlayback.swift")
        let body = try XCTUnwrap(source.extractedRuntimeFunctionBody(named: "seekRuntimeBGMToBeginning"))

        XCTAssertTrue(body.contains("BGMReturnToStartSmoothingPolicy.plan"))
        XCTAssertTrue(body.contains("cleanupBag.bgmReturnToStartTask?.cancel()"))
        XCTAssertTrue(body.contains("runBGMReturnToStartFade"))
        XCTAssertTrue(body.contains("runtime.state.bgm.generation == generation"))
        XCTAssertTrue(body.contains("runtime.state.panic.isActive"))
    }

    func testSeekRuntimeBGMToProgressStillClampsProgress() {
        var state = LiveRuntimeState()
        let item = bgmItem()
        state.bgm.items = [item]
        state.bgm.currentID = item.id
        state.bgm.generation = 3
        state.bgm.duration = 20
        let viewModel = makeViewModel()
        viewModel.runtime.replaceStateForFacadeSync(state, clearActionLog: true)

        viewModel.seekRuntimeBGM(toProgress: 2, generation: 3)

        XCTAssertLessThanOrEqual(viewModel.bgmProgress, 1)
    }

    func testStartBGMTimerStillUsesGenerationBoundTimer() {
        let viewModel = makeViewModel()

        viewModel.startBGMTimer(generation: 4)

        XCTAssertEqual(viewModel.activeBGMTimerGenerationForTesting, 4)
        XCTAssertTrue(viewModel.bgmProgressTimerForTesting?.isValid == true)
    }

    func testStopBGMTimerStillIgnoresStaleGeneration() {
        let viewModel = makeViewModel()
        viewModel.startBGMTimer(generation: 4)

        viewModel.stopBGMTimer(generation: 3)

        XCTAssertEqual(viewModel.activeBGMTimerGenerationForTesting, 4)
        XCTAssertTrue(viewModel.bgmProgressTimerForTesting?.isValid == true)
    }

    func testFallbackEndObserverStillDispatchesBGMFinishForCurrentGenerationOnly() {
        let viewModel = makeViewModel()
        let item = bgmItem()
        viewModel.bgmItems = [item]
        viewModel.toggleBGM(item)
        let fallbackItem = viewModel.bgmFallbackPlayer.currentItem

        NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: fallbackItem)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "bgmReachedEnd" })
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "ViewModelBGMRuntimePlaybackBehaviorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults)
        viewModel.liveAudioFadeDuration = 0
        return viewModel
    }

    private func bgmItem() -> BGMItem {
        BGMItem(title: "Walk-in", url: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).mp3"))
    }

    private func replaceRuntimeBGMState(
        in viewModel: SwitcherViewModel,
        item: BGMItem,
        phase: BGMPlaybackPhase,
        generation: Int,
        effectiveBGM: Float,
        isBGMMuted: Bool = false
    ) {
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        state.bgm.currentID = item.id
        state.bgm.phase = phase
        state.bgm.generation = generation
        state.bgm.currentTime = 4
        state.bgm.duration = 10
        state.bgm.progress = 0.4
        state.audio.effectiveBGM = effectiveBGM
        state.audio.isBGMMuted = isBGMMuted
        viewModel.runtime.replaceStateForFacadeSync(state, clearActionLog: true)
        viewModel.bgmProgressStore.update(currentTime: 4, duration: 10)
    }
}
