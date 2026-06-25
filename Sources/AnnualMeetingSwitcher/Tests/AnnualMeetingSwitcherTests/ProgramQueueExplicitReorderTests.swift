import XCTest
@testable import LiveSwitcher

final class ProgramQueueDropPlanTests: XCTestCase {
    func testFirstItemDropsAfterLastItem() {
        let ids = makeIDs(count: 3)
        let plan = ProgramQueueDropPlan(draggedID: ids[0], targetID: ids[2], placement: .after)

        XCTAssertEqual(plan.resolvedMove(in: ids)?.fromOffsets, IndexSet(integer: 0))
        XCTAssertEqual(plan.resolvedMove(in: ids)?.toOffset, 3)
        XCTAssertEqual(plan.resolvedOrder(in: ids), [ids[1], ids[2], ids[0]])
    }

    func testLastItemDropsBeforeFirstItem() {
        let ids = makeIDs(count: 3)
        let plan = ProgramQueueDropPlan(draggedID: ids[2], targetID: ids[0], placement: .before)

        XCTAssertEqual(plan.resolvedMove(in: ids)?.fromOffsets, IndexSet(integer: 2))
        XCTAssertEqual(plan.resolvedMove(in: ids)?.toOffset, 0)
        XCTAssertEqual(plan.resolvedOrder(in: ids), [ids[2], ids[0], ids[1]])
    }

    func testAdjacentMoveDownUsesAfterPlacement() {
        let ids = makeIDs(count: 3)
        let plan = ProgramQueueDropPlan(draggedID: ids[0], targetID: ids[1], placement: .after)

        XCTAssertEqual(plan.resolvedMove(in: ids)?.fromOffsets, IndexSet(integer: 0))
        XCTAssertEqual(plan.resolvedMove(in: ids)?.toOffset, 2)
        XCTAssertEqual(plan.resolvedOrder(in: ids), [ids[1], ids[0], ids[2]])
    }

    func testAdjacentMoveUpUsesBeforePlacement() {
        let ids = makeIDs(count: 3)
        let plan = ProgramQueueDropPlan(draggedID: ids[1], targetID: ids[0], placement: .before)

        XCTAssertEqual(plan.resolvedMove(in: ids)?.fromOffsets, IndexSet(integer: 1))
        XCTAssertEqual(plan.resolvedMove(in: ids)?.toOffset, 0)
        XCTAssertEqual(plan.resolvedOrder(in: ids), [ids[1], ids[0], ids[2]])
    }

    func testInvalidIDsAndNoopMovesDoNotResolve() {
        let ids = makeIDs(count: 3)

        XCTAssertNil(ProgramQueueDropPlan(draggedID: UUID(), targetID: ids[1], placement: .before).resolvedMove(in: ids))
        XCTAssertNil(ProgramQueueDropPlan(draggedID: ids[0], targetID: UUID(), placement: .before).resolvedMove(in: ids))
        XCTAssertNil(ProgramQueueDropPlan(draggedID: ids[0], targetID: ids[0], placement: .after).resolvedMove(in: ids))
        XCTAssertNil(ProgramQueueDropPlan(draggedID: ids[0], targetID: ids[1], placement: .before).resolvedMove(in: ids))
    }

    private func makeIDs(count: Int) -> [UUID] {
        (0..<count).map { _ in UUID() }
    }
}

@MainActor
final class ProgramQueueExplicitReorderViewModelTests: XCTestCase {
    func testMoveProgramItemByIDKeepsCurrentProgramAndMediaRuntimeStable() {
        let first = programItem("First")
        let current = programItem("Current")
        let third = programItem("Third")
        let viewModel = makeViewModel(items: [first, current, third], current: current, mediaPlaying: true)
        let initialGeneration = viewModel.runtime.state.media.generation

        let didMove = viewModel.moveProgramItem(
            draggedID: third.id,
            targetID: first.id,
            placement: .before
        )

        XCTAssertTrue(didMove)
        XCTAssertEqual(viewModel.programItems.map(\.id), [third.id, first.id, current.id])
        XCTAssertEqual(viewModel.currentProgramItem?.id, current.id)
        XCTAssertEqual(viewModel.runtime.state.program.currentID, current.id)
        XCTAssertTrue(viewModel.runtime.state.media.isPlaying)
        XCTAssertEqual(viewModel.runtime.state.media.generation, initialGeneration)
        XCTAssertEqual(actionCount("operatorMovedProgramItems", in: viewModel), 1)
    }

    func testMoveProgramItemByIDNoopsForInvalidIDs() {
        let first = programItem("First")
        let second = programItem("Second")
        let viewModel = makeViewModel(items: [first, second], current: first)

        let didMove = viewModel.moveProgramItem(
            draggedID: UUID(),
            targetID: second.id,
            placement: .after
        )

        XCTAssertFalse(didMove)
        XCTAssertEqual(viewModel.programItems.map(\.id), [first.id, second.id])
        XCTAssertEqual(actionCount("operatorMovedProgramItems", in: viewModel), 0)
    }

    func testMoveProgramItemByIDSavesNewOrderSnapshot() {
        let first = programItem("First")
        let second = programItem("Second")
        let viewModel = makeViewModel(items: [first, second], current: nil)
        var savedOrder: [UUID] = []
        viewModel.testHooks.saveDataDidRun = {
            savedOrder = viewModel.programItems.map(\.id)
        }

        _ = viewModel.moveProgramItem(draggedID: first.id, targetID: second.id, placement: .after)

        XCTAssertEqual(savedOrder, [second.id, first.id])
    }

    func testMoveProgramItemByIDRecomputesNextPlayableFromNewOrder() {
        let current = programItem("Current")
        let firstNext = programItem("First Next")
        let secondNext = programItem("Second Next")
        let viewModel = makeViewModel(items: [current, firstNext, secondNext], current: current)

        XCTAssertEqual(
            ProgramQueueStore.nextPlayableIndexAfterCurrent(current: current, in: viewModel.programItems),
            1
        )

        _ = viewModel.moveProgramItem(draggedID: secondNext.id, targetID: firstNext.id, placement: .before)

        XCTAssertEqual(viewModel.programItems.map(\.id), [current.id, secondNext.id, firstNext.id])
        XCTAssertEqual(
            ProgramQueueStore.nextPlayableIndexAfterCurrent(current: current, in: viewModel.programItems),
            1
        )
        XCTAssertEqual(viewModel.programItems[1].id, secondNext.id)
    }

    func testRemoveProgramItemsSnapshotsIDsBeforeDeletingNonContiguousIndexes() {
        let first = programItem("First")
        let second = programItem("Second")
        let third = programItem("Third")
        let fourth = programItem("Fourth")
        let viewModel = makeViewModel(items: [first, second, third, fourth], current: nil)

        viewModel.removeProgramItems(at: IndexSet([1, 3]))

        XCTAssertEqual(viewModel.programItems.map(\.id), [first.id, third.id])
        XCTAssertEqual(
            viewModel.runtime.actionLog.filter { $0.actionName == "operatorRemovedProgramItem" }.count,
            2
        )
    }

    func testRemoveProgramItemsIgnoresOutOfRangeIndexes() {
        let first = programItem("First")
        let second = programItem("Second")
        let viewModel = makeViewModel(items: [first, second], current: nil)

        viewModel.removeProgramItems(at: IndexSet([0, 5]))

        XCTAssertEqual(viewModel.programItems.map(\.id), [second.id])
    }

    private func makeViewModel(
        items: [ProgramItem],
        current: ProgramItem?,
        mediaPlaying: Bool = false
    ) -> SwitcherViewModel {
        var state = LiveRuntimeState()
        state.program.items = items
        state.program.currentID = current?.id
        state.media.loadedURL = current?.sourceURL
        state.media.isPlaying = mediaPlaying
        state.media.generation = 9
        let runtime = LiveRuntimeStore(
            initialState: state,
            effectRunner: .recording(),
            environment: .productionProgramSelectionOwning()
        )
        let suiteName = "ProgramQueueExplicitReorderViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let viewModel = SwitcherViewModel(
            loadPersistedData: false,
            enableSystemVolumeObserver: false,
            userDefaults: defaults,
            runtime: runtime
        )
        viewModel.syncProgramQueueFacadeFromRuntime()
        if let current {
            viewModel.applyCurrentProgramProjectionFromRuntime(current, switchedAt: Date(timeIntervalSince1970: 100))
        }
        return viewModel
    }

    private func programItem(_ title: String) -> ProgramItem {
        ProgramItem(title: title, subtitle: "MEDIA", sourceURL: URL(fileURLWithPath: "/tmp/\(title).mp4"))
    }

    private func actionCount(_ name: String, in viewModel: SwitcherViewModel) -> Int {
        viewModel.runtime.actionLog.filter { $0.actionName == name }.count
    }
}

final class ProgramQueueExplicitReorderSourceTests: XCTestCase {
    func testLeftPanelUsesExplicitHandleDropAndSafeDeleteSnapshot() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/LeftPanel.swift")

        XCTAssertTrue(source.contains("onHandleDragEnded:"))
        XCTAssertTrue(source.contains("@State private var draggedProgramItemID"))
        XCTAssertTrue(source.contains("@State private var programQueueRowFrames"))
        XCTAssertTrue(source.contains("programQueueDropTarget(at:"))
        XCTAssertTrue(source.contains("finishProgramQueueDrag(draggedID:"))
        XCTAssertTrue(source.contains("viewModel.moveProgramItem("))
        XCTAssertTrue(source.contains("viewModel.removeProgramItems(at: indexSet)"))
        XCTAssertFalse(source.contains(".onMove"))
        XCTAssertFalse(source.contains("viewModel.programItems[$0]"))
    }

    func testRunQueueRowExposesDragHandleWithoutWholeRowDragging() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/RunQueueView.swift")

        XCTAssertTrue(source.contains("struct ProgramQueueDragHandle"))
        XCTAssertTrue(source.contains("line.3.horizontal"))
        XCTAssertTrue(source.contains("DragGesture(minimumDistance: 2, coordinateSpace: .global)"))
        XCTAssertTrue(source.contains("onHandleDragChanged"))
        XCTAssertTrue(source.contains("manualDropPlacement"))
        XCTAssertTrue(source.contains("ProgramQueueRowFramePreferenceKey"))
        XCTAssertFalse(source.contains("Button(action: {})"))
        XCTAssertFalse(source.contains("ProgramQueueRowDropDelegate"))
        XCTAssertFalse(source.contains(".onDrop("))
        XCTAssertFalse(source.contains(".draggable(item.id"))
        XCTAssertFalse(source.contains("registeredTypeIdentifiers.contains"))
    }

    func testRunQueueUsesLocalDragSessionInsteadOfPasteboardMetadata() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/Views/RunQueueView.swift")

        XCTAssertTrue(source.contains("ProgramQueueDropPreview"))
        XCTAssertTrue(source.contains("ProgramQueueRowFramePreferenceKey"))
        XCTAssertFalse(source.contains("NSItemProvider"))
        XCTAssertFalse(source.contains("suggestedName"))
    }

    func testViewModelProgramQueueDoesNotMutateFacadeQueueDirectlyForIDReorder() throws {
        let source = try repositorySource("Sources/AnnualMeetingSwitcher/Sources/AnnualMeetingSwitcher/ViewModel+ProgramQueue.swift")
        let body = try XCTUnwrap(source.balancedBlock(after: "func moveProgramItem("))

        XCTAssertTrue(body.contains("ProgramQueueDropPlan"))
        XCTAssertTrue(body.contains("moveProgramItems(from:"))
        XCTAssertFalse(body.contains("programItems.move"))
    }
}
