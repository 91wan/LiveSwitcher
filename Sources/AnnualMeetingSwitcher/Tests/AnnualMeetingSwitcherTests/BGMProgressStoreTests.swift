import XCTest
@testable import LiveSwitcher

@MainActor
final class BGMProgressStoreTests: XCTestCase {
    func testTimerIntervalIsOperatorFriendlyFiveFPS() {
        XCTAssertEqual(BGMProgressStore.updateInterval, 0.2, accuracy: 0.0001)
    }

    func testUpdateCalculatesProgressAndDuration() {
        let store = BGMProgressStore()

        store.update(currentTime: 25, duration: 100)

        XCTAssertEqual(store.currentTime, 25)
        XCTAssertEqual(store.duration, 100)
        XCTAssertEqual(store.progress, 0.25, accuracy: 0.0001)
    }

    func testUpdateClampsProgressAndHandlesUnknownDuration() {
        let store = BGMProgressStore()

        store.update(currentTime: 125, duration: 100)
        XCTAssertEqual(store.currentTime, 100)
        XCTAssertEqual(store.progress, 1, accuracy: 0.0001)

        store.update(currentTime: 8, duration: 0)
        XCTAssertEqual(store.currentTime, 8)
        XCTAssertNil(store.duration)
        XCTAssertEqual(store.progress, 0)
    }

    func testResetClearsProgressState() {
        let store = BGMProgressStore()
        store.update(currentTime: 12, duration: 60)

        store.reset()

        XCTAssertEqual(store.progress, 0)
        XCTAssertEqual(store.currentTime, 0)
        XCTAssertNil(store.duration)
    }

    func testFallbackDurationPolicyUsesStoredDurationFirstThenCurrentItemDuration() {
        XCTAssertEqual(
            BGMFallbackDurationPolicy.knownDuration(storedDuration: 90, itemDuration: 120),
            90
        )
        XCTAssertEqual(
            BGMFallbackDurationPolicy.knownDuration(storedDuration: nil, itemDuration: 120),
            120
        )
        XCTAssertNil(BGMFallbackDurationPolicy.knownDuration(storedDuration: 0, itemDuration: .infinity))
        XCTAssertNil(BGMFallbackDurationPolicy.knownDuration(storedDuration: nil, itemDuration: .nan))
    }

    func testViewModelNoLongerPublishesBGMProgressTriplet() throws {
        let viewModel = try sourceText("ViewModel.swift")
        let playback = try sourceText("ViewModel+BGMRuntimePlayback.swift")

        XCTAssertFalse(viewModel.contains("@Published var bgmProgress: Double"))
        XCTAssertFalse(viewModel.contains("@Published var bgmCurrentTime: Double"))
        XCTAssertFalse(viewModel.contains("@Published var bgmDuration: Double?"))
        XCTAssertFalse(viewModel.contains("@Published var bgmRealtimeLevelDB"))
        XCTAssertFalse(playback.contains("withTimeInterval: 1.0 / 30.0"))
        XCTAssertTrue(viewModel.contains("let bgmProgressStore = BGMProgressStore()"))
        XCTAssertTrue(playback.contains("withTimeInterval: BGMProgressStore.updateInterval"))
    }

    func testBGMPlaylistProgressBarObservesDedicatedStore() throws {
        let source = try sourceText("Views/BGMPlaylistPanel.swift")

        XCTAssertTrue(source.contains("BGMProgressBar(progressStore: viewModel.bgmProgressStore"))
        XCTAssertTrue(source.contains("@ObservedObject var progressStore: BGMProgressStore"))
        XCTAssertFalse(source.contains("get: { viewModel.bgmProgress }"))
    }

    func testBGMSwitchingUsesOwnedFadeTransitionInsteadOfImmediateHardStop() throws {
        let playback = try sourceText("ViewModel+BGMRuntimePlayback.swift")
        let cleanupBag = try sourceText("Models/ViewModelCleanupBag.swift")
        let controls = try sourceText("ViewModel+BGMControls.swift")

        XCTAssertTrue(cleanupBag.contains("bgmTransitionTasks"))
        XCTAssertTrue(cleanupBag.contains("bgmTransitionTasks.values.forEach"))
        XCTAssertTrue(playback.contains("cleanupBag.bgmTransitionTasks"))
        XCTAssertTrue(playback.contains("releaseRetiredBGMPlayerAfterFade"))
        XCTAssertFalse(controls.contains("bgmAudioPlayer?.stop()"))
    }

    func testRemovingCurrentBGMUsesFadeReleaseInsteadOfImmediateHardStop() throws {
        let source = try sourceText("ViewModel+BGMControls.swift")
        let removeBody = try XCTUnwrap(source.functionBody(named: "removeBGMItem"))

        XCTAssertFalse(removeBody.contains("bgmAudioPlayer?.stop()"))
        XCTAssertTrue(removeBody.contains(".facadeBGMLibraryChanged"))
        XCTAssertFalse(removeBody.contains(".operatorStoppedBGM"))
    }

    func testFallbackBGMProgressTimerSamplesFallbackPlayerTime() throws {
        let source = try sourceText("ViewModel+BGMRuntimePlayback.swift")
        let updateBody = try XCTUnwrap(source.functionBody(named: "updateBGMProgress"))

        XCTAssertTrue(updateBody.contains("bgmFallbackPlayer.currentTime()"))
        XCTAssertTrue(updateBody.contains(".bgmProgressUpdated"))
        XCTAssertTrue(updateBody.contains("syncBGMFacadeFromRuntime"))
    }

    func testBGMSeekUsesFallbackDurationPolicyForAVPlayerFallbackItems() throws {
        let source = try sourceText("ViewModel+BGMRuntimePlayback.swift")
        let seekBody = try XCTUnwrap(source.functionBody(named: "seekRuntimeBGM(toProgress"))
        let beginningBody = try XCTUnwrap(source.functionBody(named: "seekRuntimeBGMToBeginning"))

        XCTAssertTrue(source.contains("private func fallbackBGMKnownDuration()"))
        XCTAssertTrue(source.contains("BGMFallbackDurationPolicy.knownDuration"))
        XCTAssertTrue(source.contains("bgmFallbackPlayer.currentItem?.duration.seconds"))
        XCTAssertTrue(seekBody.contains("fallbackBGMKnownDuration()"))
        XCTAssertTrue(beginningBody.contains("fallbackBGMKnownDuration()"))
    }

    func testBGMProgressTimerIgnoresStaleTransitionGeneration() throws {
        let source = try sourceText("ViewModel+BGMRuntimePlayback.swift")
        let startBody = try XCTUnwrap(source.functionBody(named: "startBGMTimer(generation: Int)"))

        XCTAssertTrue(startBody.contains("self.activeBGMTimerGenerationForRuntime() == generation"))
        XCTAssertTrue(startBody.contains("updateBGMProgress(generation: generation)"))
        XCTAssertFalse(startBody.contains("Task { @MainActor"))
    }

    func testViewModelDeinitInvalidatesBGMProgressTimer() throws {
        var viewModel: SwitcherViewModel? = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: isolatedDefaults()
        )
        viewModel?.startBGMTimer(generation: 1)
        let timer = WeakTimerBox(try XCTUnwrap(viewModel).bgmProgressTimerForTesting)
        XCTAssertTrue(timer.value?.isValid == true)

        viewModel = nil

        XCTAssertFalse(timer.value?.isValid ?? true)
    }

    func testStoppingBGMUsesSingleRoutingFadeBeforePausing() throws {
        let controls = try sourceText("ViewModel+BGMControls.swift")
        let playback = try sourceText("ViewModel+BGMRuntimePlayback.swift")
        let audioRouting = try sourceText("ViewModel+AudioRouting.swift")
        let toggleBody = try XCTUnwrap(controls.functionBody(named: "toggleBGM"))

        XCTAssertTrue(playback.contains("fadeCurrentBGMPlayerVolume"))
        XCTAssertTrue(toggleBody.contains("dispatchRuntimeFacadeAction(.operatorStoppedBGM)"))
        XCTAssertTrue(audioRouting.contains("applyAudioRoutingForRuntimeChange"))
        XCTAssertTrue(playback.contains("BGMFadeCompletionPolicy.pauseDelay"))
        XCTAssertFalse(toggleBody.contains("fadeCurrentBGMPlayerVolume(to: 0, duration: fadeDur)"))
        XCTAssertFalse(toggleBody.contains("bgmAudioPlayer?.setVolume(0, fadeDuration: fadeDur)"))
        XCTAssertFalse(toggleBody.contains("capturedPlayer?.volume = 0"))
    }

    func testFadeCompletionPolicyAddsSettleTimeBeforePause() {
        XCTAssertEqual(BGMFadeCompletionPolicy.pauseDelay(fadeDuration: 0), 0)
        XCTAssertGreaterThan(BGMFadeCompletionPolicy.pauseDelay(fadeDuration: 1.0), 1.0)
        XCTAssertLessThanOrEqual(BGMFadeCompletionPolicy.pauseDelay(fadeDuration: 1.0), 1.1)
    }

    func testBGMReleaseUsesCompletionPolicySettleDelay() throws {
        let source = try sourceText("ViewModel+BGMRuntimePlayback.swift")
        let playerReleaseBody = try XCTUnwrap(source.functionBody(named: "releaseRetiredBGMPlayerAfterFade"))
        let fallbackReleaseBody = try XCTUnwrap(source.functionBody(named: "releaseBGMFallbackAfterFade"))

        XCTAssertTrue(playerReleaseBody.contains("BGMFadeCompletionPolicy.pauseDelay"))
        XCTAssertTrue(fallbackReleaseBody.contains("BGMFadeCompletionPolicy.pauseDelay"))
        XCTAssertFalse(playerReleaseBody.contains("UInt64(duration * 1_000_000_000)"))
        XCTAssertFalse(fallbackReleaseBody.contains("UInt64(duration * 1_000_000_000)"))
    }

    private func sourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: sourceURL(relativePath), encoding: .utf8)
    }

    private func sourceURL(_ relativePath: String) throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            let candidate = directory
                .appendingPathComponent("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher")
                .appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        throw XCTSkip("Could not locate \(relativePath) from test source path.")
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "LiveSwitcher.BGMProgressStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

}

private final class WeakTimerBox {
    weak var value: Timer?

    init(_ value: Timer?) {
        self.value = value
    }
}

private extension String {
    func functionBody(named functionName: String) -> String? {
        guard let nameRange = range(of: "func \(functionName)") else { return nil }
        guard let openingBrace = self[nameRange.lowerBound...].firstIndex(of: "{") else { return nil }

        var depth = 0
        var index = openingBrace
        while index < endIndex {
            let character = self[index]
            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(self[openingBrace...index])
                }
            }
            index = self.index(after: index)
        }
        return nil
    }
}
