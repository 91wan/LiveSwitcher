import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramSelectionRuntimeFacadeSyncTests: XCTestCase {
    func testSelectionActionsSyncCurrentProgramFacade() {
        let item = programItem("Current")
        let viewModel = makeViewModel(initialItems: [item], bridgeMode: .programSelectionOwned)

        viewModel.dispatchRuntimeFacadeAction(.operatorSelectedProgram(item.id))

        XCTAssertEqual(viewModel.currentProgramItem, item)
        XCTAssertEqual(viewModel.currentProgramSwitchedAt, viewModel.runtime.state.program.currentSwitchedAt)
    }

    func testDetachedSelectionSyncsCurrentProgramFacade() {
        let detached = programItem("Detached")
        let viewModel = makeViewModel(initialItems: [programItem("Queued")], bridgeMode: .programSelectionOwned)

        viewModel.dispatchRuntimeFacadeAction(.operatorSelectedDetachedProgram(detached))

        XCTAssertEqual(viewModel.currentProgramItem, detached)
        XCTAssertEqual(viewModel.currentProgramSwitchedAt, viewModel.runtime.state.program.currentSwitchedAt)
    }

    func testRemovedCurrentQueueItemSyncsNilCurrentProgramFacade() {
        let item = programItem("Removed")
        var state = LiveRuntimeState()
        state.program.items = [item]
        state.program.currentID = item.id
        state.program.currentSwitchedAt = Date(timeIntervalSince1970: 50)
        let viewModel = makeViewModel(initialState: state, bridgeMode: .programSelectionOwned)
        viewModel.syncProgramQueueFacadeFromRuntime()
        viewModel.syncCurrentProgramFacadeFromRuntime()

        viewModel.dispatchRuntimeFacadeAction(.operatorRemovedProgramItem(item.id))

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentProgramSwitchedAt)
    }

    func testScheduleUpdateSyncsCurrentProgramFacadeFromRuntime() {
        let item = programItem("Scheduled")
        var state = LiveRuntimeState()
        state.program.items = [item]
        state.program.currentID = item.id
        state.program.currentSwitchedAt = Date(timeIntervalSince1970: 50)
        let start = Date(timeIntervalSince1970: 100)
        let viewModel = makeViewModel(initialState: state, bridgeMode: .programSelectionOwned)
        viewModel.syncProgramQueueFacadeFromRuntime()
        viewModel.syncCurrentProgramFacadeFromRuntime()

        viewModel.dispatchRuntimeFacadeAction(.operatorUpdatedProgramItemSchedule(
            id: item.id,
            scheduledStartAt: start,
            scheduledDuration: 30
        ))

        XCTAssertEqual(viewModel.currentProgramItem?.scheduledStartAt, start)
        XCTAssertEqual(viewModel.currentProgramItem?.scheduledDuration, 30)
    }

    func testProjectionHelperUpdatesCurrentProgramWithoutRuntimeDispatch() {
        let item = programItem("Projected")
        let viewModel = makeViewModel(initialItems: [item], bridgeMode: .programSelectionOwned)

        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date(timeIntervalSince1970: 10))

        XCTAssertEqual(viewModel.currentProgramItem, item)
        XCTAssertEqual(viewModel.currentProgramSwitchedAt, Date(timeIntervalSince1970: 10))
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "facadeCurrentProgramChanged" })
    }

    func testClearCurrentProgramSelectionDispatchesRuntimeClearWhenOwned() {
        let item = programItem("Current")
        let viewModel = makeViewModel(initialItems: [item], bridgeMode: .programSelectionOwned)
        viewModel.dispatchRuntimeFacadeAction(.operatorSelectedProgram(item.id))

        viewModel.clearCurrentProgramSelection(reason: .htmlPresentationEnded)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentProgramSwitchedAt)
        XCTAssertTrue(viewModel.runtime.actionLog.contains { $0.actionName == "operatorClearedCurrentProgram" })
    }

    func testClearCurrentProgramSelectionFallsBackWithoutRuntimeDispatchWhenSelectionNotOwned() {
        let item = programItem("Current")
        let viewModel = makeViewModel(initialItems: [item], bridgeMode: .programQueueOwned)
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date(timeIntervalSince1970: 10))

        viewModel.clearCurrentProgramSelection(reason: .operatorCleared)

        XCTAssertNil(viewModel.currentProgramItem)
        XCTAssertNil(viewModel.currentProgramSwitchedAt)
        XCTAssertFalse(viewModel.runtime.actionLog.contains { $0.actionName == "operatorClearedCurrentProgram" })
    }

    func testProgramSelectionFacadeSyncPolicyIncludesCurrentProgramActions() {
        for action in currentProgramSyncActions {
            XCTAssertTrue(LiveRuntimeFacadeSyncPolicy.options(for: action).syncCurrentProgram, action.redactedName)
        }
    }

    func testClearCurrentProgramSelectionSyncsCurrentProgramOnly() {
        let options = LiveRuntimeFacadeSyncPolicy.options(for: .operatorClearedCurrentProgram(reason: .operatorCleared))

        XCTAssertTrue(options.syncCurrentProgram)
        XCTAssertFalse(options.dispatchAudioInputsChanged)
        XCTAssertFalse(options.syncBGM)
        XCTAssertFalse(options.syncProjection)
        XCTAssertFalse(options.syncPPT)
        XCTAssertFalse(options.syncAutomationNotice)
        XCTAssertFalse(options.syncSupport)
        XCTAssertFalse(options.syncProgramQueue)
    }

    func testPresentationQueryRequestCompletedAndFailedDoNotSyncCurrentProgram() {
        let id = UUID()
        for action in [
            LiveRuntimeAction.operatorRequestedPresentationQuery(id: id),
            .presentationQueryCompleted(id: id, result: .empty),
            .presentationQueryFailed(id: id, action: "keynote.scan.windows", sanitizedMessage: "permissionDenied")
        ] {
            XCTAssertFalse(LiveRuntimeFacadeSyncPolicy.options(for: action).syncCurrentProgram, action.redactedName)
        }
    }

    private var currentProgramSyncActions: [LiveRuntimeAction] {
        let item = programItem("Action")
        return [
            .operatorSelectedProgram(item.id),
            .operatorSelectedDetachedProgram(item),
            .operatorClearedCurrentProgram(reason: .operatorCleared),
            .facadeCurrentProgramChanged(item.id),
            .operatorRemovedProgramItem(item.id),
            .facadeLoadedProgramQueue([item]),
            .operatorUpdatedProgramItemSchedule(id: item.id, scheduledStartAt: nil, scheduledDuration: nil),
            .presentationQueryResultConsumed(id: UUID())
        ]
    }

    private func makeViewModel(
        initialItems: [ProgramItem] = [],
        bridgeMode: LiveRuntimeBridgeMode
    ) -> SwitcherViewModel {
        var state = LiveRuntimeState()
        state.program.items = initialItems
        return makeViewModel(initialState: state, bridgeMode: bridgeMode)
    }

    private func makeViewModel(
        initialState: LiveRuntimeState,
        bridgeMode: LiveRuntimeBridgeMode
    ) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            initialState: initialState,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        let suiteName = "ProgramSelectionRuntimeFacadeSyncTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults, runtime: runtime)
    }

    private func programItem(_ title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "MEDIA", sourceURL: URL(fileURLWithPath: "/tmp/\(title).mp4"))
    }
}
