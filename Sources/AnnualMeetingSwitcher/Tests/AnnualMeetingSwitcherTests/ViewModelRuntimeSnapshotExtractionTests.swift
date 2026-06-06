import XCTest
@testable import LiveSwitcher

@MainActor
final class ViewModelRuntimeSnapshotExtractionTests: XCTestCase {
    func testRuntimeSnapshotBuilderIsNotDeclaredInViewModel() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel.swift")

        XCTAssertFalse(source.contains("func makeRuntimeStateSnapshot("))
        XCTAssertFalse(source.contains("func runtimeAudioInputsMatch("))
        XCTAssertFalse(source.contains("func audioFacadeSnapshot("))
        XCTAssertFalse(source.contains("func syncBGMLibraryIntoRuntimeSnapshot("))
        XCTAssertFalse(source.contains("func syncSupportIntoRuntimeSnapshot("))
    }

    func testRuntimeSnapshotBuilderLivesInRuntimeSnapshotExtension() throws {
        let source = try XCTUnwrap(runtimeSnapshotSource())

        XCTAssertTrue(source.contains("extension SwitcherViewModel"))
        XCTAssertTrue(source.contains("func syncRuntimeStateFromFacade(clearActionLog: Bool)"))
        XCTAssertTrue(source.contains("func makeRuntimeStateSnapshot() -> LiveRuntimeState"))
    }

    func testRuntimeSnapshotPreservesSupportWhenSupportOwned() {
        var state = LiveRuntimeState()
        state.support.record(kind: .projectionStarted, detail: "source=runtime", at: Date(timeIntervalSince1970: 100))
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .supportOwned)

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.support, state.support)
    }

    func testRuntimeSnapshotPreservesAutomationNoticeWhenAutomationNoticeOwned() throws {
        var state = LiveRuntimeState()
        let notice = AutomationRuntimeNoticePolicy.make(action: "keynote.next-slide")
        state.automation.notice = notice
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .automationNoticeOwned)
        viewModel.automationRuntimeNotice = nil

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.automation.notice, notice)
    }

    func testRuntimeSnapshotPreservesPPTWhenPPTOwned() {
        var state = LiveRuntimeState()
        state.ppt.isRequested = true
        state.ppt.isEventTapActive = true
        state.ppt.lastFailureReason = "accessibilityPermission"
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .pptOwned)
        viewModel.isPageInterceptEnabled = false

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.ppt, state.ppt)
    }

    func testRuntimeSnapshotPreservesProjectionWhenProjectionOwned() {
        var state = LiveRuntimeState()
        state.projection.isBroadcasting = true
        state.projection.safetyNotice = "runtime notice"
        state.projection.lastDisplayLostAt = Date(timeIntervalSince1970: 100)
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .projectionOwned)
        viewModel.isBroadcasting = false
        viewModel.broadcastSafetyNotice = nil

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertTrue(viewModel.runtime.state.projection.isBroadcasting)
        XCTAssertEqual(viewModel.runtime.state.projection.safetyNotice, "runtime notice")
        XCTAssertEqual(viewModel.runtime.state.projection.lastDisplayLostAt, Date(timeIntervalSince1970: 100))
    }

    func testRuntimeSnapshotPreservesBGMPlaybackWhenBGMOwned() {
        let item = BGMItem(title: "Runtime", url: URL(fileURLWithPath: "/tmp/runtime.mp3"))
        var state = LiveRuntimeState()
        state.bgm.items = [item]
        state.bgm.currentID = item.id
        state.bgm.isPlaying = true
        state.bgm.progress = 0.7
        state.bgm.currentTime = 7
        state.bgm.duration = 10
        state.bgm.generation = 6
        let viewModel = makeViewModel(runtimeState: state, bridgeMode: .bgmOwned)
        viewModel.bgmItems = [item]
        viewModel.currentBGMItem = nil
        viewModel.isBGMPlaying = false

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.bgm.currentID, item.id)
        XCTAssertTrue(viewModel.runtime.state.bgm.isPlaying)
        XCTAssertEqual(viewModel.runtime.state.bgm.progress, 0.7, accuracy: 0.0001)
        XCTAssertEqual(viewModel.runtime.state.bgm.generation, 6)
    }

    func testRuntimeSnapshotStillMirrorsProgramQueue() {
        let first = ProgramItem(title: "Video", subtitle: "VIDEO", sourceURL: URL(fileURLWithPath: "/tmp/video.mp4"))
        let second = ProgramItem(title: "HTML", subtitle: "HTML", sourceURL: URL(fileURLWithPath: "/tmp/index.html"))
        let viewModel = makeViewModel(runtimeState: LiveRuntimeState(), bridgeMode: .recordingOnly)
        viewModel.applyProgramQueueProjectionFromRuntime([first, second])
        viewModel.currentProgramItem = second

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.program.items, [first, second])
        XCTAssertEqual(viewModel.runtime.state.program.currentID, second.id)
    }

    func testRuntimeSnapshotStillMirrorsPanicSnapshotOnly() {
        let currentProgramID = UUID()
        let currentBGMID = UUID()
        let snapshot = PanicPlaybackSnapshot(
            currentProgramID: currentProgramID,
            wasMediaPlaying: true,
            currentBGMID: currentBGMID,
            wasBGMPlaying: false
        )
        let viewModel = makeViewModel(runtimeState: LiveRuntimeState(), bridgeMode: .recordingOnly)
        viewModel.isPanicMode = true
        viewModel.panicPlaybackSnapshot = snapshot

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertTrue(viewModel.runtime.state.panic.isActive)
        XCTAssertEqual(viewModel.runtime.state.panic.snapshot, snapshot)
    }

    func testRuntimeAudioInputsMatchBehaviorUnchanged() {
        let viewModel = makeViewModel(runtimeState: LiveRuntimeState(), bridgeMode: .recordingOnly)
        viewModel.syncRuntimeStateFromFacade(clearActionLog: true)
        let actionLogCount = viewModel.runtime.actionLog.count

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.actionLog.count, actionLogCount)
    }

    private func runtimeSnapshotSource() throws -> String? {
        try optionalRepositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+RuntimeSnapshot.swift")
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
