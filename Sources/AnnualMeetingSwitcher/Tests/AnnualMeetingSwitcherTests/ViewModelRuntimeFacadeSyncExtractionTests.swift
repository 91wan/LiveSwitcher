import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelRuntimeFacadeSyncExtractionTests: XCTestCase {
    func testRuntimeFacadeSyncHelpersAreNotDeclaredInViewModel() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")

        XCTAssertFalse(source.contains("func syncBGMFacadeFromRuntime("))
        XCTAssertFalse(source.contains("func syncProjectionFacadeFromRuntime("))
        XCTAssertFalse(source.contains("func syncPPTFacadeFromRuntime("))
        XCTAssertFalse(source.contains("func syncAutomationNoticeFacadeFromRuntime("))
        XCTAssertFalse(source.contains("func syncSupportFacadeFromRuntime("))
    }

    func testRuntimeFacadeSyncHelpersLiveInRuntimeFacadeSyncExtension() throws {
        let source = try XCTUnwrap(runtimeFacadeSyncSource())

        XCTAssertTrue(source.contains("extension SwitcherViewModel"))
        XCTAssertTrue(source.contains("func syncBGMFacadeFromRuntime()"))
        XCTAssertTrue(source.contains("func syncProjectionFacadeFromRuntime()"))
        XCTAssertTrue(source.contains("func syncPPTFacadeFromRuntime()"))
        XCTAssertTrue(source.contains("func syncAutomationNoticeFacadeFromRuntime()"))
        XCTAssertTrue(source.contains("func syncSupportFacadeFromRuntime()"))
    }

    func testSyncBGMFacadeFromRuntimeBehaviorUnchanged() {
        let item = BGMItem(title: "Runtime", url: URL(fileURLWithPath: "/tmp/runtime.mp3"))
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        state.bgm.currentID = item.id
        state.bgm.isPlaying = true
        state.bgm.progress = 0.4
        state.bgm.currentTime = 4
        state.bgm.duration = 10
        state.bgm.playMode = .sequential
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .bgmOwned)

        viewModel.syncBGMFacadeFromRuntime()

        XCTAssertEqual(viewModel.currentBGMItem?.id, item.id)
        XCTAssertTrue(viewModel.isBGMPlaying)
        XCTAssertEqual(viewModel.bgmProgress, 0.4, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bgmPlayMode, .sequential)
    }

    func testSyncProjectionFacadeFromRuntimeBehaviorUnchanged() {
        var state = LiveRuntimeState()
        state.projection.isBroadcasting = true
        state.projection.safetyNotice = "runtime projection"
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .projectionOwned)

        viewModel.syncProjectionFacadeFromRuntime()

        XCTAssertTrue(viewModel.isBroadcasting)
        XCTAssertEqual(viewModel.broadcastSafetyNotice, "runtime projection")
    }

    func testSyncPPTFacadeFromRuntimeBehaviorUnchanged() {
        var state = LiveRuntimeState()
        state.ppt.isEventTapActive = true
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .pptOwned)

        viewModel.syncPPTFacadeFromRuntime()

        XCTAssertTrue(viewModel.isPageInterceptEnabled)
    }

    func testSyncAutomationNoticeFacadeFromRuntimeBehaviorUnchanged() {
        var state = LiveRuntimeState()
        let notice = AutomationRuntimeNoticePolicy.make(action: "keynote.next-slide")
        state.automation.notice = notice
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .automationNoticeOwned)

        viewModel.syncAutomationNoticeFacadeFromRuntime()

        XCTAssertEqual(viewModel.automationRuntimeNotice, notice)
    }

    func testSyncSupportFacadeFromRuntimeBehaviorUnchanged() {
        var state = LiveRuntimeState()
        state.support.record(kind: .projectionStarted, detail: "source=runtime", at: Date(timeIntervalSince1970: 100))
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .supportOwned)

        viewModel.syncSupportFacadeFromRuntime()

        XCTAssertEqual(viewModel.supportEvents, state.support.events)
    }

    func testLegacySupportFacadeSyncIsRemovedOrCompatibilityOnly() throws {
        let source = try XCTUnwrap(runtimeFacadeSyncSource())

        if source.contains("syncLegacySupportFacadeFromRuntime") {
            XCTAssertTrue(source.contains("guard !runtime.bridgeMode.owns(.support) else"))
        }
    }

    private func runtimeFacadeSyncSource() throws -> String? {
        try optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeFacadeSync.swift")
    }

    private func makeViewModel(
        runtimeState: LiveRuntimeState,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            initialState: runtimeState,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        let viewModel = SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, runtime: runtime)
        viewModel.runtime.replaceStateForFacadeSync(runtimeState, clearActionLog: true)
        return viewModel
    }
}
