import XCTest
@testable import LiveSwitcher

@MainActor
final class ProgramQueueRuntimeFacadeSyncTests: XCTestCase {
    func testProgramQueueOwnedFacadeSyncMirrorsRuntimeItems() {
        let item = programItem("Runtime")
        var state = LiveRuntimeState()
        state.program.items = [item]
        let viewModel = makeViewModel(initialState: state, bridgeMode: .programQueueOwned)

        viewModel.syncProgramQueueFacadeFromRuntime()

        XCTAssertEqual(viewModel.programItems, [item])
    }

    func testNonProgramQueueOwnedFacadeSyncPreservesViewModelItems() {
        let runtimeItem = programItem("Runtime")
        let facadeItem = programItem("Facade")
        var state = LiveRuntimeState()
        state.program.items = [runtimeItem]
        let viewModel = makeViewModel(initialState: state, bridgeMode: .presentationQueryOwned)
        viewModel.applyProgramQueueProjectionFromRuntime([facadeItem])

        viewModel.syncProgramQueueFacadeFromRuntime()

        XCTAssertEqual(viewModel.programItems, [facadeItem])
    }

    func testAddedProgramItemsSyncsProgramItemsFacade() {
        let viewModel = makeViewModel(bridgeMode: .programQueueOwned)
        let item = programItem("Added")

        viewModel.dispatchRuntimeFacadeAction(.operatorAddedProgramItems([item]))

        XCTAssertEqual(viewModel.programItems, [item])
    }

    func testRemovedProgramItemSyncsProgramItemsFacade() {
        let item = programItem("Removed")
        var state = LiveRuntimeState()
        state.program.items = [item]
        let viewModel = makeViewModel(initialState: state, bridgeMode: .programQueueOwned)
        viewModel.applyProgramQueueProjectionFromRuntime([item])

        viewModel.dispatchRuntimeFacadeAction(.operatorRemovedProgramItem(item.id))

        XCTAssertTrue(viewModel.programItems.isEmpty)
    }

    func testMovedProgramItemsSyncsProgramItemsFacade() {
        let first = programItem("First")
        let second = programItem("Second")
        var state = LiveRuntimeState()
        state.program.items = [first, second]
        let viewModel = makeViewModel(initialState: state, bridgeMode: .programQueueOwned)
        viewModel.syncProgramQueueFacadeFromRuntime()

        viewModel.dispatchRuntimeFacadeAction(.operatorMovedProgramItems(fromOffsets: [0], toOffset: 2))

        XCTAssertEqual(viewModel.programItems.map(\.id), [second.id, first.id])
    }

    func testUpdatedProgramItemScheduleSyncsProgramItemsFacade() {
        let item = programItem("Scheduled")
        let start = Date(timeIntervalSince1970: 100)
        var state = LiveRuntimeState()
        state.program.items = [item]
        let viewModel = makeViewModel(initialState: state, bridgeMode: .programQueueOwned)

        viewModel.dispatchRuntimeFacadeAction(.operatorUpdatedProgramItemSchedule(
            id: item.id,
            scheduledStartAt: start,
            scheduledDuration: 30
        ))

        XCTAssertEqual(viewModel.programItems.first?.scheduledStartAt, start)
        XCTAssertEqual(viewModel.programItems.first?.scheduledDuration, 30)
    }

    func testFacadeLoadedProgramQueueSyncsProgramItemsFacade() {
        let viewModel = makeViewModel(bridgeMode: .programQueueOwned)
        let item = programItem("Loaded")

        viewModel.dispatchRuntimeFacadeAction(.facadeLoadedProgramQueue([item]))

        XCTAssertEqual(viewModel.programItems, [item])
    }

    func testPresentationQueryCompletedDoesNotSyncProgramQueueFacade() {
        let existing = programItem("Existing")
        let viewModel = makeViewModel(bridgeMode: .programQueueOwned)
        viewModel.applyProgramQueueProjectionFromRuntime([existing])
        let id = UUID()

        viewModel.runtime.dispatch(.operatorRequestedPresentationQuery(id: id))
        viewModel.dispatchRuntimeFacadeAction(.presentationQueryCompleted(id: id, result: .empty))

        XCTAssertEqual(viewModel.programItems, [existing])
    }

    func testPresentationQueryResultConsumedSyncsProgramQueueFacade() {
        let item = programItem("Runtime")
        var state = LiveRuntimeState()
        state.program.items = [item]
        let viewModel = makeViewModel(initialState: state, bridgeMode: .programQueueOwned)

        viewModel.dispatchRuntimeFacadeAction(.presentationQueryResultConsumed(id: UUID()))

        XCTAssertEqual(viewModel.programItems, [item])
    }

    func testProgramQueueActionsDoNotDispatchAudioInputs() {
        for action in programQueueActions {
            XCTAssertFalse(LiveRuntimeFacadeSyncPolicy.options(for: action).dispatchAudioInputsChanged, action.redactedName)
        }
    }

    func testProgramQueueOwnedRuntimeSnapshotPreservesRuntimeItems() {
        let runtimeItem = programItem("Runtime")
        let staleFacadeItem = programItem("Stale")
        var state = LiveRuntimeState()
        state.program.items = [runtimeItem]
        let viewModel = makeViewModel(initialState: state, bridgeMode: .programQueueOwned)
        viewModel.applyProgramQueueProjectionFromRuntime([staleFacadeItem])

        viewModel.dispatchRuntimeFacadeAction(.operatorSetShowAgendaTimeline(true))

        XCTAssertEqual(viewModel.runtime.state.program.items, [runtimeItem])
    }

    func testProgramQueueOwnedRuntimeSnapshotStillMirrorsCurrentProgramID() {
        let item = programItem("Current")
        var state = LiveRuntimeState()
        state.program.items = [item]
        let viewModel = makeViewModel(initialState: state, bridgeMode: .programQueueOwned)
        viewModel.applyCurrentProgramProjectionFromRuntime(item, switchedAt: Date())

        viewModel.dispatchRuntimeFacadeAction(.operatorSetShowAgendaTimeline(true))

        XCTAssertEqual(viewModel.runtime.state.program.currentID, item.id)
    }

    func testProgramQueueOwnedRuntimeSnapshotStillMirrorsDetachedCurrentProgram() {
        let runtimeItem = programItem("Runtime")
        let detached = programItem("Detached")
        var state = LiveRuntimeState()
        state.program.items = [runtimeItem]
        let viewModel = makeViewModel(initialState: state, bridgeMode: .programQueueOwned)
        viewModel.applyCurrentProgramProjectionFromRuntime(detached, switchedAt: Date())

        viewModel.dispatchRuntimeFacadeAction(.operatorSetShowAgendaTimeline(true))

        XCTAssertEqual(viewModel.runtime.state.program.currentDetachedItem, detached)
    }

    func testProgramQueueOwnedRuntimeSnapshotDoesNotOverwriteRuntimeItemsWithStaleFacade() {
        let runtimeItem = programItem("Runtime")
        let staleFacadeItem = programItem("Stale")
        var state = LiveRuntimeState()
        state.program.items = [runtimeItem]
        let viewModel = makeViewModel(initialState: state, bridgeMode: .programQueueOwned)
        viewModel.applyProgramQueueProjectionFromRuntime([staleFacadeItem])

        viewModel.syncRuntimeStateFromFacade(clearActionLog: false)

        XCTAssertEqual(viewModel.runtime.state.program.items, [runtimeItem])
    }

    private var programQueueActions: [LiveRuntimeAction] {
        let item = programItem("Action")
        return [
            .operatorAddedProgramItems([item]),
            .operatorRemovedProgramItem(item.id),
            .operatorMovedProgramItems(fromOffsets: [0], toOffset: 1),
            .operatorUpdatedProgramItemSchedule(id: item.id, scheduledStartAt: nil, scheduledDuration: nil),
            .operatorAddedAgendaMarker(AgendaMarkerInput(title: "茶歇", scheduledStartAt: nil, duration: 15 * 60)),
            .operatorUpdatedAgendaMarker(id: item.id, input: AgendaMarkerInput(title: "转场", scheduledStartAt: nil, duration: 10 * 60)),
            .facadeLoadedProgramQueue([item])
        ]
    }

    private func makeViewModel(
        initialState: LiveRuntimeState = LiveRuntimeState(),
        bridgeMode: LiveRuntimeBridgeMode
    ) -> SwitcherViewModel {
        let runtime = LiveRuntimeStore(
            initialState: initialState,
            effectRunner: .recording(),
            environment: LiveRuntimeEnvironment(bridgeMode: bridgeMode)
        )
        let suiteName = "ProgramQueueRuntimeFacadeSyncTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SwitcherViewModel(loadPersistedData: false, enableSystemVolumeObserver: false, userDefaults: defaults, runtime: runtime)
    }

    private func programItem(_ title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "MEDIA", sourceURL: URL(fileURLWithPath: "/tmp/\(title).mp4"))
    }
}
