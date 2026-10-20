import XCTest
import AVFoundation
@testable import LiveSwitcher

@MainActor
final class RuntimeBridgeSlimmingTests: XCTestCase {
    func testViewModelDoesNotDefineClosureRuntimePorts() throws {
        let viewModel = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
        let closurePorts = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeClosurePorts.swift")

        XCTAssertFalse(viewModel.contains("private final class Closure"))
        XCTAssertFalse(viewModel.contains("final class Closure"))
        for name in [
            "ClosureAudioRoutingPort",
            "ClosureMediaPlaybackPort",
            "ClosureBGMPlaybackPort",
            "ClosureBGMTimerPort",
            "ClosureAutomationNoticePort",
            "ClosureSupportEventPort",
            "ClosureAutomationPort",
            "ClosureProjectionPort",
            "ClosureImageAssetPort",
            "ClosurePersistencePort",
            "ClosurePPTEventTapPort"
        ] {
            XCTAssertFalse(viewModel.contains("private final class \(name)"), name)
            XCTAssertFalse(viewModel.contains("final class \(name)"), name)
            XCTAssertTrue(closurePorts.contains(name), name)
        }
    }

    func testBGMPreparationRetiresPreviousAudioPlayerThroughCleanupBag() async throws {
        let viewModel = makeViewModel()
        let url = try makeAudioFixture()
        let retired = try AVAudioPlayer(contentsOf: url)
        defer { retired.stop(); viewModel.bgmAudioPlayer?.stop() }
        retired.delegate = viewModel.bgmDelegate
        viewModel.bgmAudioPlayer = retired
        viewModel.liveAudioFadeDuration = 0.03
        XCTAssertTrue(retired.play())
        XCTAssertTrue(retired.isPlaying)
        XCTAssertNotNil(retired.delegate)
        let previousTaskIDs = Set(viewModel.cleanupBag.bgmTransitionTasks.keys)
        let item = BGMItem(title: "Replacement", url: url, category: .warmUp)

        viewModel.prepareRuntimeBGMPlayer(item, generation: viewModel.runtime.state.bgm.generation)
        let current = try XCTUnwrap(viewModel.bgmAudioPlayer)
        XCTAssertFalse(current === retired)
        let taskIDs = Set(viewModel.cleanupBag.bgmTransitionTasks.keys).subtracting(previousTaskIDs)
        XCTAssertFalse(taskIDs.isEmpty)
        let tasks = try taskIDs.map { try XCTUnwrap(viewModel.cleanupBag.bgmTransitionTasks[$0]) }
        for task in tasks { await task.value }

        XCTAssertFalse(retired.isPlaying)
        XCTAssertNil(retired.delegate)
        XCTAssertEqual(retired.volume, 0, accuracy: 0.0001)
        XCTAssertTrue(viewModel.bgmAudioPlayer === current)
        for taskID in taskIDs { XCTAssertNil(viewModel.cleanupBag.bgmTransitionTasks[taskID]) }
    }

    func testBGMFallbackRetirementReleasesCleanupBagRegistryEntry() async throws {
        let viewModel = makeViewModel()
        let retired = AVPlayer(playerItem: AVPlayerItem(url: try makeAudioFixture()))
        retired.volume = 0.5
        viewModel.bgmFallbackPlayer = retired
        XCTAssertNotNil(retired.currentItem)
        let previousTaskIDs = Set(viewModel.cleanupBag.bgmTransitionTasks.keys)

        viewModel.retireCurrentBGMFallbackPlayerForSwitch(duration: 0)
        let taskID = try XCTUnwrap(Set(viewModel.cleanupBag.bgmTransitionTasks.keys).subtracting(previousTaskIDs).first)
        let task = try XCTUnwrap(viewModel.cleanupBag.bgmTransitionTasks[taskID])
        XCTAssertFalse(viewModel.bgmFallbackPlayer === retired)
        XCTAssertTrue(viewModel.cleanupBag.retiredBGMFallbackPlayers[taskID] === retired)
        await task.value

        XCTAssertFalse(task.isCancelled)
        XCTAssertEqual(retired.volume, 0)
        XCTAssertEqual(retired.rate, 0)
        XCTAssertNil(retired.currentItem)
        XCTAssertNil(viewModel.cleanupBag.retiredBGMFallbackPlayers[taskID])
        XCTAssertNil(viewModel.cleanupBag.bgmTransitionTasks[taskID])
    }

    func testCurrentBGMFallbackFadeUsesRuntimeGenerationGuard() async throws {
        let viewModel = makeViewModel()
        let current = AVPlayer(playerItem: AVPlayerItem(url: try makeAudioFixture()))
        viewModel.bgmFallbackPlayer = current
        defer { current.pause(); current.replaceCurrentItem(with: nil) }
        var state = viewModel.runtime.state
        state.bgm.generation = 2
        viewModel.runtime.replaceStateForFacadeSync(state)

        for duration in [0.0, 0.03] {
            current.volume = 0.8
            viewModel.fadeCurrentBGMFallbackVolume(to: 0.1, duration: duration, generation: 1)
            if duration > 0 {
                let staleTask = try XCTUnwrap(viewModel.cleanupBag.bgmFallbackVolumeFadeTask)
                await staleTask.value
            }
            XCTAssertEqual(current.volume, 0.8, accuracy: 0.0001)

            viewModel.fadeCurrentBGMFallbackVolume(to: 0.4, duration: duration, generation: state.bgm.generation)
            if duration > 0 {
                let currentTask = try XCTUnwrap(viewModel.cleanupBag.bgmFallbackVolumeFadeTask)
                await currentTask.value
            }
            XCTAssertTrue(viewModel.bgmFallbackPlayer === current)
            XCTAssertEqual(current.volume, 0.4, accuracy: 0.0001)
        }
    }

    func testRetiredBGMFallbackCleanupSurvivesRuntimeGenerationAdvance() async throws {
        let viewModel = makeViewModel()
        let retired = AVPlayer(playerItem: AVPlayerItem(url: try makeAudioFixture()))
        retired.volume = 0.8
        viewModel.bgmFallbackPlayer = retired
        XCTAssertNotNil(retired.currentItem)
        let previousTaskIDs = Set(viewModel.cleanupBag.bgmTransitionTasks.keys)

        viewModel.retireCurrentBGMFallbackPlayerForSwitch(duration: 0.03)
        let taskID = try XCTUnwrap(Set(viewModel.cleanupBag.bgmTransitionTasks.keys).subtracting(previousTaskIDs).first)
        let task = try XCTUnwrap(viewModel.cleanupBag.bgmTransitionTasks[taskID])
        XCTAssertTrue(viewModel.cleanupBag.retiredBGMFallbackPlayers[taskID] === retired)
        var state = viewModel.runtime.state
        state.bgm.generation += 1
        viewModel.runtime.replaceStateForFacadeSync(state)
        await task.value

        XCTAssertFalse(task.isCancelled)
        XCTAssertEqual(retired.volume, 0)
        XCTAssertEqual(retired.rate, 0)
        XCTAssertNil(retired.currentItem)
        XCTAssertNil(viewModel.cleanupBag.retiredBGMFallbackPlayers[taskID])
        XCTAssertNil(viewModel.cleanupBag.bgmTransitionTasks[taskID])
    }

    func testViewModelCleanupBagIsNotDeclaredInViewModel() throws {
        let viewModel = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
        let cleanupBag = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/ViewModelCleanupBag.swift")

        XCTAssertFalse(viewModel.contains("final class ViewModelCleanupBag"))
        XCTAssertTrue(cleanupBag.contains("final class ViewModelCleanupBag"))
        XCTAssertTrue(viewModel.contains("@ObservationIgnored let cleanupBag = ViewModelCleanupBag()"))
    }

    func testViewModelDoesNotDefineViewModelCleanupBag() throws {
        try testViewModelCleanupBagIsNotDeclaredInViewModel()
    }

    func testCleanupBagCancelAllStillCancelsAutomationNoticeTask() {
        let bag = ViewModelCleanupBag()
        let task = Task<Void, Never> { try? await Task.sleep(nanoseconds: 10_000_000_000) }
        bag.automationNoticeExpiryTask = task
        bag.automationNoticeExpiryTaskNoticeID = UUID()

        bag.cancelAll()

        XCTAssertTrue(task.isCancelled)
        XCTAssertNil(bag.automationNoticeExpiryTask)
        XCTAssertNil(bag.automationNoticeExpiryTaskNoticeID)
    }

    func testCleanupBagCancelAllStillCancelsBGMTasks() {
        let bag = ViewModelCleanupBag()
        let playerFadeTask = Task<Void, Never> { try? await Task.sleep(nanoseconds: 10_000_000_000) }
        let fallbackFadeTask = Task<Void, Never> { try? await Task.sleep(nanoseconds: 10_000_000_000) }
        let transitionTask = Task<Void, Never> { try? await Task.sleep(nanoseconds: 10_000_000_000) }

        bag.bgmPlayerVolumeFadeTask = playerFadeTask
        bag.bgmFallbackVolumeFadeTask = fallbackFadeTask
        bag.bgmTransitionTasks[UUID()] = transitionTask

        bag.cancelAll()

        XCTAssertTrue(playerFadeTask.isCancelled)
        XCTAssertTrue(fallbackFadeTask.isCancelled)
        XCTAssertTrue(transitionTask.isCancelled)
    }

    func testCleanupBagCancelAllStillRemovesFallbackPlayers() {
        let bag = ViewModelCleanupBag()
        let player = AVPlayer()
        let token = UUID()
        bag.retiredBGMFallbackPlayers[token] = player

        bag.cancelAll()

        XCTAssertTrue(bag.retiredBGMFallbackPlayers.isEmpty)
    }

    func testViewModelDoesNotDefineRuntimeFacadeSyncPolicy() throws {
        let viewModel = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
        let policy = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Runtime/LiveRuntimeFacadeSyncPolicy.swift")

        XCTAssertFalse(viewModel.contains("enum LiveRuntimeFacadeSyncPolicy"))
        XCTAssertFalse(viewModel.contains("struct LiveRuntimeFacadeSyncOptions"))
        XCTAssertTrue(policy.contains("enum LiveRuntimeFacadeSyncPolicy"))
    }

    func testViewModelDoesNotGrowNewShouldSyncDomainSwitches() throws {
        let viewModel = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")

        XCTAssertFalse(viewModel.contains("shouldDispatchAudioInputsBeforeRuntimeAction"))
        XCTAssertFalse(viewModel.contains("shouldSyncBGMFacadeAfterRuntimeAction"))
        XCTAssertFalse(viewModel.contains("shouldSyncProjectionFacadeAfterRuntimeAction"))
        XCTAssertFalse(viewModel.contains("shouldSyncPPTFacadeAfterRuntimeAction"))
        XCTAssertFalse(viewModel.contains("shouldSyncAutomationNoticeFacadeAfterRuntimeAction"))
        XCTAssertFalse(viewModel.contains("shouldSyncSupportFacadeAfterRuntimeAction"))
    }

    private func makeViewModel() -> SwitcherViewModel {
        let suiteName = "RuntimeBridgeSlimmingTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults
        )
    }

    private func makeAudioFixture() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RuntimeBridgeSlimmingTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("cleanup.wav")
        try BGMAudioFixture.writeSineWave(to: url, duration: 20)
        return url
    }

    private func sourceText(_ relativePath: String) throws -> String {
        let url = try repositoryRoot().appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func repositoryRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.pathComponents.count > 1 {
            directory.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("docs").path) {
                return directory
            }
        }
        throw XCTSkip("Could not locate repository root from test source path.")
    }
}
