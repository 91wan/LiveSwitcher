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

    func testBGMRuntimeCleanupCoordinatorIsNotDeclaredInViewModel() throws {
        let viewModel = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")
        let coordinator = try sourceText("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Models/BGMRuntimeCleanupCoordinator.swift")

        XCTAssertFalse(viewModel.contains("protocol BGMRuntimeCleanupHandle"))
        XCTAssertFalse(viewModel.contains("final class BGMRuntimeCleanupCoordinator"))
        XCTAssertTrue(coordinator.contains("protocol BGMRuntimeCleanupHandle"))
        XCTAssertTrue(coordinator.contains("final class BGMRuntimeCleanupCoordinator"))
    }

    func testViewModelDoesNotDefineBGMRuntimeCleanupCoordinator() throws {
        try testBGMRuntimeCleanupCoordinatorIsNotDeclaredInViewModel()
    }

    func testBGMRuntimeCleanupCoordinatorStillCompilesAndKeepsCurrentPlayerGenerationGuard() {
        let coordinator = BGMRuntimeCleanupCoordinator()
        let current = RuntimeBridgeSlimmingCleanupHandle(volume: 1)
        coordinator.currentPlayer = current
        coordinator.currentGeneration = 2

        coordinator.fadeCurrentPlayerVolume(to: 0, generation: 1)

        XCTAssertEqual(current.volume, 1)
    }

    func testBGMRuntimeCleanupCoordinatorRetiredFallbackCleanupStillRuns() {
        let coordinator = BGMRuntimeCleanupCoordinator()
        let retired = RuntimeBridgeSlimmingCleanupHandle(volume: 0.8)
        let token = coordinator.trackRetiredFallback(retired)
        coordinator.currentGeneration = 1

        coordinator.currentGeneration = 2
        coordinator.cleanupRetiredFallback(retired, token: token)

        XCTAssertEqual(retired.volume, 0)
        XCTAssertTrue(retired.didPause)
        XCTAssertTrue(retired.didClear)
        XCTAssertFalse(coordinator.hasRetiredFallback(token))
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

private final class RuntimeBridgeSlimmingCleanupHandle: BGMRuntimeCleanupHandle {
    var volume: Float
    private(set) var didPause = false
    private(set) var didClear = false

    init(volume: Float = 1) {
        self.volume = volume
    }

    func stop() {}

    func pause() {
        didPause = true
    }

    func clear() {
        didClear = true
    }
}
